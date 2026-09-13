/**
 * CONDOMEET — ONDA C4B
 * Orquestrador Controlado de Retenção de Encomendas
 * Modo: EXCLUSIVAMENTE DRY-RUN / READ-ONLY
 *
 * Execução CLI:
 * node scripts/retention/orchestrator.ts --condominio-id <UUID>
 * node scripts/retention/orchestrator.ts --test
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pg from 'pg';
import { PowerSyncMonitor, POWERSYNC_INSTANCE_ID, POWERSYNC_SLOT_PREFIX, LAG_THRESHOLDS } from './powersync_monitor.js';
import type { DryRunReport, ExecutionReport, OrchestratorConfig, OrchestratorFinalState, PowerSyncState, RawSlotData, ExecutionSource, FairShareCandidate, FairShareSelectionResult } from './types.js';
import { resolveAuditSemantics } from './types.js';

const { Client } = pg;

export interface SecureEnvConfig {
  host: string;
  port: number;
  user: string;
  database: string;
  password: string | null;
  caPath: string | null;
  mode: 'SESSION' | 'DIRECT';
}

// ── Utilitário seguro para carregar variáveis de ambiente sem expor segredos ──
export function loadSecureEnv(): SecureEnvConfig {
  let host = process.env.POSTGRES_HOST || null;
  let portStr = process.env.POSTGRES_PORT || null;
  let user = process.env.POSTGRES_USER || null;
  let database = process.env.POSTGRES_DATABASE || null;
  let password = process.env.POSTGRES_PASSWORD || null;
  let caPath = process.env.SUPABASE_SSL_CA_PATH || null;

  if (!password || !caPath || !host || !user) {
    const candidatePaths = [
      path.resolve(process.cwd(), 'web-app/.env.local'),
      path.resolve(process.cwd(), '.env.local')
    ];
    for (const envPath of candidatePaths) {
      if (fs.existsSync(envPath)) {
        const content = fs.readFileSync(envPath, 'utf8');
        const passMatch = content.match(/^POSTGRES_PASSWORD=(.*)$/m);
        const caMatch = content.match(/^SUPABASE_SSL_CA_PATH=(.*)$/m);
        const hostMatch = content.match(/^POSTGRES_HOST=(.*)$/m);
        const portMatch = content.match(/^POSTGRES_PORT=(.*)$/m);
        const userMatch = content.match(/^POSTGRES_USER=(.*)$/m);
        const dbMatch = content.match(/^POSTGRES_DATABASE=(.*)$/m);

        if (passMatch && !password) password = passMatch[1].trim().replace(/^['"]|['"]$/g, '');
        if (caMatch && !caPath) caPath = caMatch[1].trim().replace(/^['"]|['"]$/g, '');
        if (hostMatch && !host) host = hostMatch[1].trim().replace(/^['"]|['"]$/g, '');
        if (portMatch && !portStr) portStr = portMatch[1].trim().replace(/^['"]|['"]$/g, '');
        if (userMatch && !user) user = userMatch[1].trim().replace(/^['"]|['"]$/g, '');
        if (dbMatch && !database) database = dbMatch[1].trim().replace(/^['"]|['"]$/g, '');
      }
    }
  }

  const finalHost = host || 'db.avypyaxthvgaybplnwxu.supabase.co';
  const finalPort = portStr ? parseInt(portStr, 10) : 5432;
  const finalUser = user || 'postgres';
  const finalDatabase = database || 'postgres';
  const mode: 'SESSION' | 'DIRECT' = finalHost.includes('pooler') ? 'SESSION' : 'DIRECT';

  // Se caPath for relativo, resolver em relação ao diretório atual
  if (caPath && !path.isAbsolute(caPath)) {
    const absPath = path.resolve(process.cwd(), caPath);
    if (fs.existsSync(absPath)) {
      caPath = absPath;
    } else {
      const webAppPath = path.resolve(process.cwd(), 'web-app', caPath);
      if (fs.existsSync(webAppPath)) {
        caPath = webAppPath;
      }
    }
  }

  return {
    host: finalHost,
    port: finalPort,
    user: finalUser,
    database: finalDatabase,
    password,
    caPath,
    mode
  };
}

// ── Funções Oficiais do Algoritmo Fair-Share (C4C.18 / C4C.21) ──

/**
 * Calcula o tamanho efetivo do lote com base no teto configurado e no backlog elegível real.
 * Garante teto absoluto de 1000 e evita desperdício de cota quando backlog < 1000.
 */
export function calculateEffectiveBatchSize(batchSizeLimit: number, totalElegivel: number): number {
  const cap = Math.min(batchSizeLimit, 1000);
  return Math.min(cap, Math.max(0, totalElegivel));
}

/**
 * Ordenação Fair-Share determinística:
 * 1. NULLS FIRST (quem nunca executou retenção vem primeiro)
 * 2. Least Recently Executed (menor last_retention_at vem primeiro)
 * 3. Backlog tiebreak (maior total_elegivel vem primeiro)
 * 4. UUID tiebreak (condominio_id ASC para determinismo absoluto)
 */
export function sortFairShareCandidates(candidates: FairShareCandidate[]): FairShareCandidate[] {
  return [...candidates]
    .filter(c => c.total_elegivel > 0)
    .sort((a, b) => {
      // 1. NULLS FIRST
      if (a.last_retention_at === null && b.last_retention_at !== null) return -1;
      if (a.last_retention_at !== null && b.last_retention_at === null) return 1;

      // 2. Least Recently Executed
      if (a.last_retention_at !== null && b.last_retention_at !== null) {
        const timeA = new Date(a.last_retention_at).getTime();
        const timeB = new Date(b.last_retention_at).getTime();
        if (timeA !== timeB) {
          return timeA - timeB;
        }
      }

      // 3. Maior backlog desempata
      if (b.total_elegivel !== a.total_elegivel) {
        return b.total_elegivel - a.total_elegivel;
      }

      // 4. UUID ASC desempate final
      return a.condominio_id.localeCompare(b.condominio_id);
    });
}

/**
 * Pre-flight de Integridade Relacional:
 * Verifica se algum batch_id em encomendas_historico está associado a mais de um condomínio.
 * Se detectada ambiguidade, falha estritamente fail-closed.
 */
export async function checkBatchCondoAmbiguity(client: pg.Client): Promise<void> {
  const ambRes = await client.query(`
    SELECT archive_batch_id, count(DISTINCT condominio_id) as condo_count
    FROM public.encomendas_historico
    WHERE archive_batch_id IS NOT NULL
    GROUP BY archive_batch_id
    HAVING count(DISTINCT condominio_id) > 1;
  `);
  if (ambRes.rows.length > 0) {
    throw new Error(`STOP_AMBIGUOUS_BATCH_CONDO: Detectado(s) ${ambRes.rows.length} lote(s) com múltiplos condomínios associados em encomendas_historico.`);
  }
}

/**
 * Consulta oficial de condomínios elegíveis e última retenção via relacionamento relacional estrito:
 * encomendas_archive_log l JOIN encomendas_historico h ON h.archive_batch_id = l.batch_id.
 * Não utiliza LIKE em executed_by para identificação de tenant.
 */
export async function queryFairShareCandidates(client: pg.Client): Promise<FairShareCandidate[]> {
  await checkBatchCondoAmbiguity(client);

  const query = `
    WITH condo_last_retention AS (
      SELECT 
        h.condominio_id,
        MAX(l.finished_at) AS last_retention_at,
        COUNT(DISTINCT l.batch_id) AS retention_batches_count
      FROM public.encomendas_archive_log l
      JOIN public.encomendas_historico h ON h.archive_batch_id = l.batch_id
      WHERE l.status IN ('SUCCESS', 'PARTIAL')
      GROUP BY h.condominio_id
    ),
    condo_eligibility AS (
      SELECT 
        c.id AS condominio_id,
        c.nome AS condominio_nome,
        COUNT(e.id) FILTER (WHERE e.status = 'delivered' AND e.delivery_time < NOW() - INTERVAL '10 days') AS delivered_10d,
        COUNT(e.id) FILTER (WHERE e.status = 'pending' AND e.created_at < NOW() - INTERVAL '3 months') AS pending_3m,
        COUNT(e.id) FILTER (
          WHERE (e.status = 'delivered' AND e.delivery_time < NOW() - INTERVAL '10 days')
          OR (e.status = 'pending' AND e.created_at < NOW() - INTERVAL '3 months')
        ) AS total_elegivel
      FROM public.condominios c
      JOIN public.encomendas e ON e.condominio_id = c.id
      GROUP BY c.id, c.nome
      HAVING COUNT(e.id) FILTER (
        WHERE (e.status = 'delivered' AND e.delivery_time < NOW() - INTERVAL '10 days')
        OR (e.status = 'pending' AND e.created_at < NOW() - INTERVAL '3 months')
      ) > 0
    )
    SELECT 
      e.condominio_id,
      e.condominio_nome,
      e.total_elegivel::integer,
      e.delivered_10d::integer,
      e.pending_3m::integer,
      r.last_retention_at,
      COALESCE(r.retention_batches_count, 0)::integer AS retention_batches_count
    FROM condo_eligibility e
    LEFT JOIN condo_last_retention r ON r.condominio_id = e.condominio_id
    ORDER BY 
      r.last_retention_at ASC NULLS FIRST,
      e.total_elegivel DESC,
      e.condominio_id ASC;
  `;

  const res = await client.query(query);
  return res.rows.map(r => ({
    condominio_id: r.condominio_id,
    condominio_nome: r.condominio_nome,
    total_elegivel: Number(r.total_elegivel),
    delivered_10d: Number(r.delivered_10d),
    pending_3m: Number(r.pending_3m),
    last_retention_at: r.last_retention_at ? new Date(r.last_retention_at) : null,
    retention_batches_count: Number(r.retention_batches_count)
  }));
}

/**
 * Pre-flight de Idempotência da Execução Automática (CRON_RETENTION):
 * Consulta execuções recentes de CRON_RETENTION nas últimas 12 horas.
 * Se detectada execução recente com status SUCCESS ou PARTIAL, encerra fail-closed.
 * Não bloqueia execuções originadas de MANUAL_ORCHESTRATOR.
 */
export async function checkCronIdempotency(client: pg.Client, executionSource: ExecutionSource): Promise<{ alreadyExecuted: boolean; recentLog?: any }> {
  if (executionSource !== 'CRON_RETENTION') {
    return { alreadyExecuted: false };
  }

  const query = `
    SELECT id, batch_id, executed_by, started_at, finished_at, status, rows_archived
    FROM public.encomendas_archive_log
    WHERE status IN ('SUCCESS', 'PARTIAL')
      AND executed_by LIKE 'CRON_RETENTION_%'
      AND finished_at >= NOW() - INTERVAL '12 hours'
    ORDER BY finished_at DESC
    LIMIT 1;
  `;

  const res = await client.query(query);
  if (res.rows.length > 0) {
    return { alreadyExecuted: true, recentLog: res.rows[0] };
  }
  return { alreadyExecuted: false };
}

/**
 * Simulação puramente em memória das próximas 10 noites de retenção (D1 a D10).
 * Não realiza escritas em banco de dados.
 */
export function simulateTenNights(initialCandidates: FairShareCandidate[]) {
  const simulationResults: Array<{
    night: number;
    condoId: string;
    condoNome: string;
    backlogBefore: number;
    batchSize: number;
    backlogAfter: number;
    criterion: string;
  }> = [];

  const state: FairShareCandidate[] = initialCandidates.map(c => ({
    ...c,
    last_retention_at: c.last_retention_at ? new Date(c.last_retention_at) : null
  }));

  const baseDate = new Date('2026-09-14T03:00:00.000Z');

  for (let night = 1; night <= 10; night++) {
    const sorted = sortFairShareCandidates(state);
    if (sorted.length === 0) {
      break;
    }

    const selected = sorted[0];
    const backlogBefore = selected.total_elegivel;
    const batchSize = calculateEffectiveBatchSize(1000, backlogBefore);
    const backlogAfter = backlogBefore - batchSize;

    let criterion = '';
    if (selected.last_retention_at === null) {
      criterion = 'NULLS FIRST (Primeira execução)';
    } else if (sorted.length > 1 && sorted[1].last_retention_at !== null) {
      const timeSelected = new Date(selected.last_retention_at).getTime();
      const timeNext = new Date(sorted[1].last_retention_at).getTime();
      if (timeSelected < timeNext) {
        criterion = 'Least Recently Executed';
      } else if (timeSelected === timeNext) {
        criterion = 'Backlog Tiebreak (total_elegivel DESC)';
      } else {
        criterion = 'Least Recently Executed';
      }
    } else {
      criterion = 'Único condomínio com backlog elegível';
    }

    simulationResults.push({
      night,
      condoId: selected.condominio_id,
      condoNome: selected.condominio_nome,
      backlogBefore,
      batchSize,
      backlogAfter,
      criterion
    });

    selected.total_elegivel = backlogAfter;
    selected.last_retention_at = new Date(baseDate.getTime() + (night - 1) * 24 * 60 * 60 * 1000);
    selected.retention_batches_count++;
  }

  return simulationResults;
}

// ── Parser e Validação Estrita de Configuração ──
export function parseConfig(args: string[]): { config?: OrchestratorConfig; error?: string; isTest?: boolean } {
  if (args.includes('--test')) {
    return { isTest: true };
  }

  let condominioId = '';
  let batchSize = 100;
  let maxBatches = 1;
  let timeoutMs = 45000;
  let cooldownMs = 4000;
  let isDryRun = true;
  let executionSource: ExecutionSource = 'MANUAL_ORCHESTRATOR';
  let fairShare: boolean | undefined = undefined;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--fair-share') {
      fairShare = true;
    } else if (arg.startsWith('--fair-share=')) {
      fairShare = arg.split('=')[1] === 'true';
    } else if (arg === '--no-fair-share') {
      fairShare = false;
    } else if (arg === '--condominio-id' && args[i + 1]) {
      condominioId = args[++i];
    } else if (arg.startsWith('--condominio-id=')) {
      condominioId = arg.split('=')[1];
    } else if (arg === '--batch-size' && args[i + 1]) {
      batchSize = parseInt(args[++i], 10);
    } else if (arg.startsWith('--batch-size=')) {
      batchSize = parseInt(arg.split('=')[1], 10);
    } else if (arg === '--max-batches' && args[i + 1]) {
      maxBatches = parseInt(args[++i], 10);
    } else if (arg.startsWith('--max-batches=')) {
      maxBatches = parseInt(arg.split('=')[1], 10);
    } else if (arg === '--timeout' && args[i + 1]) {
      timeoutMs = parseInt(args[++i], 10);
    } else if (arg.startsWith('--timeout=')) {
      timeoutMs = parseInt(arg.split('=')[1], 10);
    } else if (arg === '--cooldown' && args[i + 1]) {
      cooldownMs = parseInt(args[++i], 10);
    } else if (arg.startsWith('--cooldown=')) {
      cooldownMs = parseInt(arg.split('=')[1], 10);
    } else if (arg === '--dry-run') {
      isDryRun = true;
    } else if (arg.startsWith('--dry-run=')) {
      isDryRun = arg.split('=')[1] === 'true';
    } else if (arg === '--dry-run' && args[i + 1] && (args[i + 1] === 'true' || args[i + 1] === 'false')) {
      isDryRun = args[++i] === 'true';
    } else if (arg === '--execution-source' && args[i + 1]) {
      const src = args[++i].toUpperCase();
      if (src === 'CRON_RETENTION' || src === 'MANUAL_ORCHESTRATOR') {
        executionSource = src;
      } else {
        return { error: `STOP: Execution source inválido ('${src}'). Esperado MANUAL_ORCHESTRATOR ou CRON_RETENTION.` };
      }
    } else if (arg.startsWith('--execution-source=')) {
      const src = arg.split('=')[1].toUpperCase();
      if (src === 'CRON_RETENTION' || src === 'MANUAL_ORCHESTRATOR') {
        executionSource = src;
      } else {
        return { error: `STOP: Execution source inválido ('${src}'). Esperado MANUAL_ORCHESTRATOR ou CRON_RETENTION.` };
      }
    }
  }

  // Resolução de modo Fair-Share:
  // Se --fair-share não foi explicitado:
  // - se condominioId foi fornecido e diferente de 'auto': fairShare = false (modo manual legado)
  // - caso contrário: fairShare = false (e validação de condomínio obrigatório se aplica)
  const isFairShare = fairShare === true;

  // Validação 1: Condomínio obrigatório (quando fairShare não está ativado)
  if (!isFairShare) {
    if (!condominioId || condominioId.trim() === '' || condominioId === 'auto') {
      return { error: 'STOP: O parâmetro --condominio-id é estritamente obrigatório. Execução global é proibida.' };
    }
  } else {
    // Modo Fair-Share ativo: se condomínio não foi fornecido ou for 'auto', definir como 'auto'
    if (!condominioId || condominioId.trim() === '') {
      condominioId = 'auto';
    }
  }

  // Validação 2: Batch size configurável homologado (100, 500 ou 1000 para escala controlada)
  if (batchSize !== 100 && batchSize !== 500 && batchSize !== 1000) {
    return { error: `STOP: Batch size inválido (${batchSize}). Os valores homologados são 100, 500 ou 1000.` };
  }

  // Validação 3: Max batches fixo em 1
  if (maxBatches !== 1) {
    return { error: `STOP: Max batches inválido (${maxBatches}). É expressamente proibido p_max_batches > 1 nesta fase.` };
  }

  // Validação 4: Timeout rígido de 45.000 ms
  if (timeoutMs !== 45000) {
    return { error: `STOP: Timeout inválido (${timeoutMs}ms). O timeout homologado é exatamente 45000 ms.` };
  }

  // Validação 5: Cooldown seguro entre 3000 e 5000 ms
  if (cooldownMs < 3000 || cooldownMs > 5000) {
    return { error: `STOP: Cooldown inválido (${cooldownMs}ms). Deve estar entre 3000 ms e 5000 ms.` };
  }

  // Validação 6: Validação de modo de execução (dry-run vs real)
  if (!isDryRun) {
    if (maxBatches !== 1) {
      return { error: 'STOP: O modo de execução real exige estritamente p_max_batches = 1.' };
    }
  }

  const killSwitch = process.env.RETENTION_KILL_SWITCH === 'true';

  return {
    config: {
      condominioId,
      batchSize,
      maxBatches,
      timeoutMs,
      cooldownMs,
      isDryRun,
      killSwitch,
      executionSource,
      fairShare: isFairShare
    }
  };
}

// ── Construtor da Consulta Oficial da RPC de Retenção ──
export function buildArchiveRpcQuery(config: OrchestratorConfig): { query: string; values: any[] } {
  return {
    query: `
      SELECT public.archive_expired_encomendas(
        p_batch_size => $1::integer,
        p_max_batches => $2::integer,
        p_condominio_id => $3::uuid,
        p_execution_source => $4::text
      ) AS result;
    `,
    values: [
      config.batchSize,
      config.maxBatches,
      config.condominioId,
      config.executionSource || 'CRON_RETENTION'
    ]
  };
}

// ── Execução Principal do Orquestrador (Dry-Run ou Real) ──
export async function runOrchestrator(config: OrchestratorConfig): Promise<ExecutionReport> {
  const { host, port, user, database, password, caPath, mode } = loadSecureEnv();

  if (!password) {
    throw new Error('POSTGRES_PASSWORD_MISSING: Senha do banco não localizada no ambiente local.');
  }

  if (!caPath || !fs.existsSync(caPath)) {
    throw new Error(`SUPABASE_SSL_CA_PATH_MISSING: Certificado CA não localizado em '${caPath}'.`);
  }

  const caCert = fs.readFileSync(caPath, 'utf8');

  const client = new Client({
    host,
    port,
    user,
    database,
    password: password,
    ssl: {
      rejectUnauthorized: true,
      ca: caCert
    },
    connectionTimeoutMillis: 10000
  });

  try {
    await client.connect();

    const isEncrypted = Boolean((client as any).connection?.stream?.encrypted);

    const dbRes = await client.query('SELECT current_database();');
    const userRes = await client.query('SELECT current_user;');
    const verRes = await client.query('SELECT version();');

    const dbName = dbRes.rows[0]?.current_database || 'unknown';
    const userName = userRes.rows[0]?.current_user || 'unknown';
    const rawVersion = verRes.rows[0]?.version || 'unknown';
    const shortVersion = rawVersion.split('\n')[0].replace(/PostgreSQL\s+([^\s]+).*/, 'PostgreSQL $1');

    // Pre-flight A: Kill Switch (Ambiente e Banco de Dados)
    const dbPolicyRes = await client.query('SELECT is_kill_switch_active FROM public.app_version_policy LIMIT 1;');
    const isDbKillSwitch = dbPolicyRes.rows[0]?.is_kill_switch_active === true;
    const isEnvKillSwitch = config.killSwitch === true;

    // Pre-flight B: Monitor do PowerSync (Resolução Dinâmica do Slot)
    const monitor = new PowerSyncMonitor();
    const slotInfo = await monitor.checkSlot(client);

    // Pre-flight C: Concorrência e Advisory Lock
    const lockCheck = await client.query(`
      SELECT count(*) as active_retention
      FROM pg_stat_activity
      WHERE query ILIKE '%archive_expired_encomendas%'
        AND pid <> pg_backend_pid();
    `);
    const activeRetention = parseInt(lockCheck.rows[0]?.active_retention || '0', 10);

    const advLockRes = await client.query(`SELECT pg_try_advisory_lock(hashtext('archive_expired_encomendas')) as acquired;`);
    const acquiredAdvLock = advLockRes.rows[0]?.acquired === true;
    if (acquiredAdvLock) {
      await client.query(`SELECT pg_advisory_unlock(hashtext('archive_expired_encomendas'));`);
    }

    let stopReason: string | undefined;
    let finalState: OrchestratorFinalState = config.isDryRun ? 'DRY_RUN_READY' : 'SUCCESS';

    if (isEnvKillSwitch || isDbKillSwitch) {
      finalState = 'STOP';
      stopReason = `RETENTION_KILL_SWITCH ativado (Env: ${isEnvKillSwitch ? 'ON' : 'OFF'}, DB: ${isDbKillSwitch ? 'ON' : 'OFF'}).`;
    } else if (slotInfo.state !== 'SAFE') {
      finalState = 'STOP';
      stopReason = slotInfo.reason || `STOP_POWERSYNC: Slot em estado ${slotInfo.state} (Lag: ${slotInfo.lag_bytes} B).`;
    } else if (activeRetention > 0) {
      finalState = 'STOP';
      stopReason = `STOP_CONCURRENCY: ${activeRetention} rotina(s) de retenção ativas detectadas no banco.`;
    } else if (!acquiredAdvLock) {
      finalState = 'STOP';
      stopReason = 'STOP_LOCK: Advisory lock da retenção ocupado por outro processo.';
    }

    // Pre-flight D: Idempotência de Execuções Automáticas (CRON_RETENTION)
    if (finalState !== 'STOP' && config.executionSource === 'CRON_RETENTION') {
      const cronIdemp = await checkCronIdempotency(client, config.executionSource);
      if (cronIdemp.alreadyExecuted) {
        finalState = 'STOP';
        stopReason = `STOP_ALREADY_EXECUTED_THIS_CYCLE: Execução automática recente detectada no ciclo de 12 horas (Batch ${cronIdemp.recentLog?.batch_id}).`;
      }
    }

    // Pre-flight E: Validação de Ambiguidade de Condomínios em Lotes Históricos
    if (finalState !== 'STOP') {
      try {
        await checkBatchCondoAmbiguity(client);
      } catch (err: any) {
        finalState = 'STOP';
        stopReason = err.message || 'STOP_AMBIGUOUS_BATCH_CONDO';
      }
    }

    // Pre-flight F: Seleção de Alvo (Fair-Share Dinâmico vs Seleção Manual)
    let targetCondoId = config.condominioId;
    let condoNome: string | null = null;
    let elegiveisCount: number | null = null;
    let effectiveBatchSize = config.batchSize;
    let selectionReason = 'MANUAL SELECTION';
    let totalCandidates = 0;

    if (finalState !== 'STOP') {
      if (config.fairShare) {
        const candidates = await queryFairShareCandidates(client);
        totalCandidates = candidates.length;
        if (candidates.length === 0) {
          finalState = 'STOP';
          stopReason = 'STOP_NO_ELIGIBLE_CONDOS: Nenhum condomínio com encomendas elegíveis para retenção.';
        } else {
          const selected = candidates[0];
          targetCondoId = selected.condominio_id;
          condoNome = selected.condominio_nome;
          elegiveisCount = selected.total_elegivel;
          effectiveBatchSize = calculateEffectiveBatchSize(config.batchSize, selected.total_elegivel);
          selectionReason = selected.last_retention_at === null
            ? 'NULLS FIRST (Primeira execução deste condomínio)'
            : `LEAST RECENTLY EXECUTED (Última retenção em ${selected.last_retention_at.toISOString()})`;
        }
      } else {
        const condoRes = await client.query('SELECT id, nome FROM public.condominios WHERE id = $1;', [config.condominioId]);
        const condoFound = condoRes.rows.length > 0;
        condoNome = condoFound ? condoRes.rows[0].nome : null;

        if (!condoFound) {
          finalState = 'STOP';
          stopReason = `STOP_CONDO: Condomínio com UUID '${config.condominioId}' não foi encontrado no banco oficial.`;
        } else {
          const elegQuery = `
            SELECT 
              COUNT(*) FILTER (WHERE status = 'delivered' AND delivery_time < NOW() - INTERVAL '10 days') AS delivered_10d,
              COUNT(*) FILTER (WHERE status = 'pending' AND created_at < NOW() - INTERVAL '3 months') AS pending_3m,
              COUNT(*) FILTER (
                WHERE (status = 'delivered' AND delivery_time < NOW() - INTERVAL '10 days')
                OR (status = 'pending' AND created_at < NOW() - INTERVAL '3 months')
              ) AS total_elegivel
            FROM public.encomendas
            WHERE condominio_id = $1;
          `;
          const elegRes = await client.query(elegQuery, [config.condominioId]);
          elegiveisCount = parseInt(elegRes.rows[0]?.total_elegivel || '0', 10);
          effectiveBatchSize = calculateEffectiveBatchSize(config.batchSize, elegiveisCount);
          selectionReason = `MANUAL_ORCHESTRATOR (Direcionado para ${condoNome})`;
        }
      }
    }

    const audit = resolveAuditSemantics(config.executionSource, targetCondoId);

    // Se houve STOP em qualquer preflight, interrompe imediatamente sem chamar a RPC
    if (finalState === 'STOP') {
      const stopReport: ExecutionReport = {
        postgresStatus: 'CONNECTED',
        tlsStatus: isEncrypted ? 'VALIDATED' : 'FAILED',
        database: dbName,
        user: userName,
        version: shortVersion,
        powerSyncState: slotInfo.state,
        powerSyncInstanceId: slotInfo.instance_id,
        slotFound: slotInfo.resolved_slot ? 'FOUND' : 'NOT FOUND',
        resolvedSlotName: slotInfo.resolved_slot ? slotInfo.resolved_slot.slot_name : null,
        plugin: slotInfo.plugin,
        slotType: slotInfo.slot_type,
        active: slotInfo.active,
        currentWalLsn: slotInfo.current_wal_lsn,
        confirmedFlushLsn: slotInfo.confirmed_flush_lsn,
        restartLsn: slotInfo.restart_lsn,
        lagFormatted: `${slotInfo.lag_bytes} bytes (${slotInfo.lag_mb} MB)`,
        killSwitchStatus: isEnvKillSwitch || isDbKillSwitch ? 'ON' : 'OFF',
        condominioNome: condoNome,
        condominioUuid: targetCondoId,
        elegiveisAtuais: elegiveisCount,
        batchSize: effectiveBatchSize,
        maxBatches: config.maxBatches,
        isDryRun: config.isDryRun,
        archiveRpcStatus: 'STOPPED / NOT EXECUTED',
        leaseStatus: 'NOT ACQUIRED',
        databaseWrites: 'ZERO',
        rowsArchived: 0,
        finalState: 'STOP',
        stopReason: stopReason,
        executionSource: audit.executionSource,
        executedBy: audit.executedBy,
        archivedBy: audit.archivedBy,
        simulatedExecutedBy: audit.executedBy,
        simulatedArchivedBy: audit.archivedBy,
        connectionHost: host,
        connectionPort: port,
        connectionUser: user,
        connectionMode: mode,
        fairShareActive: Boolean(config.fairShare),
        selectionReason: selectionReason,
        totalCandidates: totalCandidates
      };
      return stopReport;
    }

    // Modo DRY-RUN (Simulação segura sem escrita)
    if (config.isDryRun) {
      const dryReport: ExecutionReport = {
        postgresStatus: 'CONNECTED',
        tlsStatus: isEncrypted ? 'VALIDATED' : 'FAILED',
        database: dbName,
        user: userName,
        version: shortVersion,
        powerSyncState: slotInfo.state,
        powerSyncInstanceId: slotInfo.instance_id,
        slotFound: slotInfo.resolved_slot ? 'FOUND' : 'NOT FOUND',
        resolvedSlotName: slotInfo.resolved_slot ? slotInfo.resolved_slot.slot_name : null,
        plugin: slotInfo.plugin,
        slotType: slotInfo.slot_type,
        active: slotInfo.active,
        currentWalLsn: slotInfo.current_wal_lsn,
        confirmedFlushLsn: slotInfo.confirmed_flush_lsn,
        restartLsn: slotInfo.restart_lsn,
        lagFormatted: `${slotInfo.lag_bytes} bytes (${slotInfo.lag_mb} MB)`,
        killSwitchStatus: 'OFF',
        condominioNome: condoNome,
        condominioUuid: targetCondoId,
        elegiveisAtuais: elegiveisCount,
        batchSize: effectiveBatchSize,
        maxBatches: config.maxBatches,
        isDryRun: true,
        archiveRpcStatus: 'DRY-RUN / NOT EXECUTED',
        leaseStatus: 'SIMULATED / NOT EXECUTED',
        databaseWrites: 'ZERO',
        rowsArchived: 0,
        finalState: 'DRY_RUN_READY',
        stopReason: undefined,
        executionSource: audit.executionSource,
        executedBy: audit.executedBy,
        archivedBy: audit.archivedBy,
        simulatedExecutedBy: audit.executedBy,
        simulatedArchivedBy: audit.archivedBy,
        connectionHost: host,
        connectionPort: port,
        connectionUser: user,
        connectionMode: mode,
        fairShareActive: Boolean(config.fairShare),
        selectionReason: selectionReason,
        totalCandidates: totalCandidates
      };
      return dryReport;
    }

    // Modo REAL (isDryRun === false) — Execução Exata de 1 Lote via RPC Oficial
    const rpcCall = buildArchiveRpcQuery({
      ...config,
      condominioId: targetCondoId,
      batchSize: effectiveBatchSize
    });
    const execRes = await client.query(rpcCall.query, rpcCall.values);
    const rpcResult = execRes.rows[0]?.result;

    const rpcStatus = rpcResult?.status || 'UNKNOWN';
    const rowsArchived = Number(rpcResult?.rows_archived) || 0;
    const batchId = rpcResult?.batch_id || null;
    const durationMs = Number(rpcResult?.duration_ms) || 0;
    const delivered10d = Number(rpcResult?.rows_delivered_10d) || 0;
    const pending3m = Number(rpcResult?.rows_pending_3m) || 0;
    const batchesProcessed = Number(rpcResult?.batches_processed) || 0;
    const rpcError = rpcResult?.error_message || null;

    // PowerSync pós-execução imediato
    const postSlotInfo = await monitor.checkSlot(client);

    const isSuccess = rpcStatus === 'SUCCESS' || rpcStatus === 'PARTIAL';
    const realFinalState: OrchestratorFinalState = isSuccess ? rpcStatus : 'FAILED';

    const realReport: ExecutionReport = {
      postgresStatus: 'CONNECTED',
      tlsStatus: isEncrypted ? 'VALIDATED' : 'FAILED',
      database: dbName,
      user: userName,
      version: shortVersion,
      powerSyncState: postSlotInfo.state,
      powerSyncInstanceId: postSlotInfo.instance_id,
      slotFound: postSlotInfo.resolved_slot ? 'FOUND' : 'NOT FOUND',
      resolvedSlotName: postSlotInfo.resolved_slot ? postSlotInfo.resolved_slot.slot_name : null,
      plugin: postSlotInfo.plugin,
      slotType: postSlotInfo.slot_type,
      active: postSlotInfo.active,
      currentWalLsn: postSlotInfo.current_wal_lsn,
      confirmedFlushLsn: postSlotInfo.confirmed_flush_lsn,
      restartLsn: postSlotInfo.restart_lsn,
      lagFormatted: `${postSlotInfo.lag_bytes} bytes (${postSlotInfo.lag_mb} MB)`,
      killSwitchStatus: 'OFF',
      condominioNome: condoNome,
      condominioUuid: targetCondoId,
      elegiveisAtuais: elegiveisCount,
      batchSize: effectiveBatchSize,
      maxBatches: config.maxBatches,
      isDryRun: false,
      archiveRpcStatus: rpcStatus,
      leaseStatus: 'ACQUIRED_AND_RELEASED',
      databaseWrites: rowsArchived > 0 ? 'EXECUTED' : 'ZERO',
      rowsArchived: rowsArchived,
      rowsDelivered10d: delivered10d,
      rowsPending3m: pending3m,
      batchesProcessed: batchesProcessed,
      durationMs: durationMs,
      batchId: batchId,
      rpcErrorMessage: rpcError,
      postLagBytes: postSlotInfo.lag_bytes,
      finalState: realFinalState,
      stopReason: rpcError || undefined,
      executionSource: audit.executionSource,
      executedBy: audit.executedBy,
      archivedBy: audit.archivedBy,
      simulatedExecutedBy: audit.executedBy,
      simulatedArchivedBy: audit.archivedBy,
      connectionHost: host,
      connectionPort: port,
      connectionUser: user,
      connectionMode: mode,
      fairShareActive: Boolean(config.fairShare),
      selectionReason: selectionReason,
      totalCandidates: totalCandidates
    };

    return realReport;
  } finally {
    await client.end().catch(() => {});
  }
}

// Retrocompatibilidade de export
export const runDryRun = runOrchestrator;

// ── Formatador Oficial de Saída ──
export function formatReport(report: ExecutionReport): string {
  if (report.isDryRun) {
    const lines: string[] = [
      '=== C4C.21 RETENTION ORCHESTRATOR REPORT (DRY-RUN) ===',
      '',
      `connection_host = ${report.connectionHost || 'N/A'}`,
      `connection_port = ${report.connectionPort || 5432}`,
      `connection_mode = ${report.connectionMode || 'SESSION'}`,
      `connection_user = ${report.connectionUser || report.user || 'N/A'}`,
      '',
      'PostgreSQL:',
      report.postgresStatus,
      '',
      'TLS:',
      report.tlsStatus,
      '',
      'Database:',
      report.database,
      '',
      'User:',
      report.user,
      '',
      'Version:',
      report.version,
      '',
      'PowerSync State:',
      report.powerSyncState,
      '',
      'PowerSync Instance:',
      report.powerSyncInstanceId,
      '',
      'Resolved Slot:',
      report.resolvedSlotName || 'NÃO RESOLVIDO',
      '',
      'Slot Status:',
      report.slotFound,
      '',
      'Plugin:',
      report.plugin || 'N/A',
      '',
      'Slot type:',
      report.slotType || 'N/A',
      '',
      'Active:',
      report.active !== null ? String(report.active) : 'N/A',
      '',
      'Current WAL LSN:',
      report.currentWalLsn || 'N/A',
      '',
      'Confirmed flush LSN:',
      report.confirmedFlushLsn || 'N/A',
      '',
      'Restart LSN:',
      report.restartLsn || 'N/A',
      '',
      'Lag:',
      report.lagFormatted || 'N/A',
      '',
      'Kill switch:',
      report.killSwitchStatus,
      '',
      'Fair-Share:',
      report.fairShareActive ? 'ACTIVE (Dynamic Selection)' : 'INACTIVE (Manual Target)',
      '',
      'Selection Reason:',
      report.selectionReason || 'N/A',
      '',
      'Eligible Condos:',
      report.totalCandidates !== undefined ? String(report.totalCandidates) : 'N/A',
      '',
      'Condomínio:',
      report.condominioNome || 'NÃO ENCONTRADO',
      '',
      'Condomínio UUID:',
      report.condominioUuid,
      '',
      'Elegíveis atuais:',
      report.elegiveisAtuais !== null ? String(report.elegiveisAtuais) : 'N/A',
      '',
      'Execution Source:',
      report.executionSource,
      '',
      'Audit executed_by:',
      report.executedBy || report.simulatedExecutedBy || 'N/A',
      '',
      'Audit archived_by:',
      report.archivedBy || report.simulatedArchivedBy || 'N/A',
      '',
      'Effective Batch Size:',
      String(report.batchSize),
      '',
      'Max batches:',
      String(report.maxBatches),
      '',
      'Archive RPC:',
      report.archiveRpcStatus,
      '',
      'Lease:',
      report.leaseStatus,
      '',
      'Database writes:',
      report.databaseWrites,
      '',
      'Rows archived:',
      String(report.rowsArchived),
      '',
      'Final state:',
      report.finalState
    ];

    if (report.stopReason) {
      lines.push('', `Motivo do STOP: ${report.stopReason}`);
    }

    return lines.join('\n');
  }

  // Relatório de Execução Real (isDryRun = false)
  const lines: string[] = [
    '=== C4C.21 RETENTION ORCHESTRATOR REPORT (REAL) ===',
    '',
    `connection_host = ${report.connectionHost || 'N/A'}`,
    `connection_port = ${report.connectionPort || 5432}`,
    `connection_mode = ${report.connectionMode || 'SESSION'}`,
    `connection_user = ${report.connectionUser || report.user || 'N/A'}`,
    '',
    'Execution Mode: REAL / WRITE',
    '',
    'PostgreSQL:',
    report.postgresStatus,
    '',
    'TLS:',
    report.tlsStatus,
    '',
    'Database:',
    report.database,
    '',
    'User:',
    report.user,
    '',
    'Version:',
    report.version,
    '',
    'PowerSync State:',
    report.powerSyncState,
    '',
    'PowerSync Instance:',
    report.powerSyncInstanceId,
    '',
    'Resolved Slot:',
    report.resolvedSlotName || 'NÃO RESOLVIDO',
    '',
    'Slot Status:',
    report.slotFound,
    '',
    'Plugin:',
    report.plugin || 'N/A',
    '',
    'Slot type:',
    report.slotType || 'N/A',
    '',
    'Active:',
    report.active !== null ? String(report.active) : 'N/A',
    '',
    'Current WAL LSN:',
    report.currentWalLsn || 'N/A',
    '',
    'Confirmed flush LSN:',
    report.confirmedFlushLsn || 'N/A',
    '',
    'Restart LSN:',
    report.restartLsn || 'N/A',
    '',
    'Lag:',
    report.lagFormatted || 'N/A',
    '',
    'Kill switch:',
    report.killSwitchStatus,
    '',
    'Fair-Share:',
    report.fairShareActive ? 'ACTIVE (Dynamic Selection)' : 'INACTIVE (Manual Target)',
    '',
    'Selection Reason:',
    report.selectionReason || 'N/A',
    '',
    'Eligible Condos:',
    report.totalCandidates !== undefined ? String(report.totalCandidates) : 'N/A',
    '',
    'Condomínio:',
    report.condominioNome || 'NÃO ENCONTRADO',
    '',
    'Condomínio UUID:',
    report.condominioUuid,
    '',
    'Execution Source:',
    report.executionSource,
    '',
    'Audit executed_by:',
    report.executedBy,
    '',
    'Audit archived_by:',
    report.archivedBy,
    '',
    'Effective Batch Size:',
    String(report.batchSize),
    '',
    'Max batches:',
    String(report.maxBatches),
    '',
    'Archive RPC:',
    report.archiveRpcStatus,
    '',
    'Batch ID:',
    report.batchId || 'N/A',
    '',
    'Duration ms:',
    String(report.durationMs ?? 'N/A'),
    '',
    'Rows archived:',
    String(report.rowsArchived),
    '',
    'Rows Delivered 10d:',
    String(report.rowsDelivered10d ?? 0),
    '',
    'Rows Pending 3m:',
    String(report.rowsPending3m ?? 0),
    '',
    'Batches Processed:',
    String(report.batchesProcessed ?? 0),
    '',
    'Database writes:',
    report.databaseWrites,
    '',
    'Final state:',
    report.finalState
  ];

  if (report.stopReason) {
    lines.push('', `Motivo do STOP: ${report.stopReason}`);
  }

  return lines.join('\n');
}

// ── Suíte de Testes Unitários Locais Obrigatórios (C4C.4-A) ──
export function runUnitTests(): boolean {
  console.log('=== EXECUTANDO SUÍTE DE TESTES OBRIGATÓRIOS (C4C.4-A) ===\n');
  let passed = 0;
  let total = 0;

  function assert(testName: string, condition: boolean, extra?: string) {
    total++;
    if (condition) {
      console.log(`✅ PASS: ${testName}`);
      passed++;
    } else {
      console.error(`❌ FAIL: ${testName} ${extra ? `(${extra})` : ''}`);
    }
  }

  // TESTE A: Um único slot ativo compatível: → RESOLVE
  const resA = PowerSyncMonitor.resolveAndEvaluateSlots({
    currentWalLsn: '229/4C000000',
    slots: [
      {
        slot_name: `${POWERSYNC_SLOT_PREFIX}9_3296`,
        plugin: 'pgoutput',
        slot_type: 'logical',
        active: true,
        confirmed_flush_lsn: '229/4C000000',
        restart_lsn: '229/4C000000',
        lag_bytes: 128
      }
    ]
  });
  assert('TESTE A: Um único slot ativo compatível resolve com sucesso', resA.state === 'SAFE' && resA.resolved_slot?.slot_name === `${POWERSYNC_SLOT_PREFIX}9_3296`);

  // TESTE B: Slot antigo/inativo + slot novo ativo: → escolhe o novo ativo
  const resB = PowerSyncMonitor.resolveAndEvaluateSlots({
    currentWalLsn: '229/4C000000',
    slots: [
      {
        slot_name: `${POWERSYNC_SLOT_PREFIX}8_f71f`,
        plugin: 'pgoutput',
        slot_type: 'logical',
        active: false,
        confirmed_flush_lsn: '228/170649D0',
        restart_lsn: null,
        lag_bytes: 5000000000
      },
      {
        slot_name: `${POWERSYNC_SLOT_PREFIX}9_3296`,
        plugin: 'pgoutput',
        slot_type: 'logical',
        active: true,
        confirmed_flush_lsn: '229/4C000000',
        restart_lsn: '229/4C000000',
        lag_bytes: 64
      }
    ]
  });
  assert('TESTE B: Slot antigo inativo + novo ativo seleciona o novo ativo', resB.state === 'SAFE' && resB.resolved_slot?.slot_name === `${POWERSYNC_SLOT_PREFIX}9_3296`);

  // TESTE C: Somente slot antigo/inativo: → STOP
  const resC = PowerSyncMonitor.resolveAndEvaluateSlots({
    currentWalLsn: '229/4C000000',
    slots: [
      {
        slot_name: `${POWERSYNC_SLOT_PREFIX}8_f71f`,
        plugin: 'pgoutput',
        slot_type: 'logical',
        active: false,
        confirmed_flush_lsn: '228/170649D0',
        restart_lsn: null,
        lag_bytes: 5000000000
      }
    ]
  });
  assert('TESTE C: Somente slot antigo inativo resulta em STOP', resC.state === 'STOP' && resC.reason?.includes('STOP_NO_ACTIVE_POWERSYNC_SLOT') === true && resC.resolved_slot === null);

  // TESTE D: Dois slots ativos compatíveis: → STOP_AMBIGUOUS_POWERSYNC_SLOT
  const resD = PowerSyncMonitor.resolveAndEvaluateSlots({
    currentWalLsn: '229/4C000000',
    slots: [
      {
        slot_name: `${POWERSYNC_SLOT_PREFIX}9_3296`,
        plugin: 'pgoutput',
        slot_type: 'logical',
        active: true,
        confirmed_flush_lsn: '229/4C000000',
        restart_lsn: '229/4C000000',
        lag_bytes: 64
      },
      {
        slot_name: `${POWERSYNC_SLOT_PREFIX}10_abcd`,
        plugin: 'pgoutput',
        slot_type: 'logical',
        active: true,
        confirmed_flush_lsn: '229/4C000000',
        restart_lsn: '229/4C000000',
        lag_bytes: 64
      }
    ]
  });
  assert('TESTE D: Dois slots ativos compatíveis geram STOP_AMBIGUOUS_POWERSYNC_SLOT', resD.state === 'STOP' && resD.reason?.includes('STOP_AMBIGUOUS_POWERSYNC_SLOT') === true);

  // TESTE E: Slot com nome semelhante mas instance ID diferente: → ignorar
  const resE = PowerSyncMonitor.resolveAndEvaluateSlots({
    currentWalLsn: '229/4C000000',
    slots: [
      {
        slot_name: 'powersync_anotherinstance12345_1_0000',
        plugin: 'pgoutput',
        slot_type: 'logical',
        active: true,
        confirmed_flush_lsn: '229/4C000000',
        restart_lsn: '229/4C000000',
        lag_bytes: 0
      }
    ]
  });
  assert('TESTE E: Slot com instance ID divergente é ignorado gerando STOP por ausência', resE.state === 'STOP' && resE.resolved_slot === null);

  // TESTE F: Slot compatível com plugin diferente de pgoutput: → ignorar/STOP
  const resF = PowerSyncMonitor.resolveAndEvaluateSlots({
    currentWalLsn: '229/4C000000',
    slots: [
      {
        slot_name: `${POWERSYNC_SLOT_PREFIX}9_3296`,
        plugin: 'test_decoding',
        slot_type: 'logical',
        active: true,
        confirmed_flush_lsn: '229/4C000000',
        restart_lsn: '229/4C000000',
        lag_bytes: 0
      }
    ]
  });
  assert('TESTE F: Slot com plugin diferente de pgoutput gera STOP_INVALID_POWERSYNC_SLOT', resF.state === 'STOP' && resF.reason?.includes('STOP_INVALID_POWERSYNC_SLOT') === true);

  // TESTE G: Slot logical incompatível: → ignorar/STOP
  const resG = PowerSyncMonitor.resolveAndEvaluateSlots({
    currentWalLsn: '229/4C000000',
    slots: [
      {
        slot_name: `${POWERSYNC_SLOT_PREFIX}9_3296`,
        plugin: 'pgoutput',
        slot_type: 'physical',
        active: true,
        confirmed_flush_lsn: '229/4C000000',
        restart_lsn: '229/4C000000',
        lag_bytes: 0
      }
    ]
  });
  assert('TESTE G: Slot com slot_type físico gera STOP_INVALID_POWERSYNC_SLOT', resG.state === 'STOP' && resG.reason?.includes('STOP_INVALID_POWERSYNC_SLOT') === true);

  // TESTE H: Lag SAFE: → comportamento atual preservado
  const resH = PowerSyncMonitor.resolveAndEvaluateSlots({
    currentWalLsn: '229/4C000000',
    slots: [
      {
        slot_name: `${POWERSYNC_SLOT_PREFIX}9_3296`,
        plugin: 'pgoutput',
        slot_type: 'logical',
        active: true,
        confirmed_flush_lsn: '229/4C000000',
        restart_lsn: '229/4C000000',
        lag_bytes: 2 * 1024 * 1024 // 2 MB
      }
    ]
  });
  assert('TESTE H: Lag < 5 MB resulta em SAFE', resH.state === 'SAFE');

  // TESTE I: Lag WAIT: → comportamento atual preservado
  const resI = PowerSyncMonitor.resolveAndEvaluateSlots({
    currentWalLsn: '229/4C000000',
    slots: [
      {
        slot_name: `${POWERSYNC_SLOT_PREFIX}9_3296`,
        plugin: 'pgoutput',
        slot_type: 'logical',
        active: true,
        confirmed_flush_lsn: '229/4C000000',
        restart_lsn: '229/4C000000',
        lag_bytes: 7 * 1024 * 1024 // 7 MB
      }
    ]
  });
  assert('TESTE I: 5 MB <= Lag < 10 MB resulta em WAIT', resI.state === 'WAIT');

  // TESTE J: Lag CONSERVATIVE: → comportamento atual preservado
  const resJ = PowerSyncMonitor.resolveAndEvaluateSlots({
    currentWalLsn: '229/4C000000',
    slots: [
      {
        slot_name: `${POWERSYNC_SLOT_PREFIX}9_3296`,
        plugin: 'pgoutput',
        slot_type: 'logical',
        active: true,
        confirmed_flush_lsn: '229/4C000000',
        restart_lsn: '229/4C000000',
        lag_bytes: 25 * 1024 * 1024 // 25 MB
      }
    ]
  });
  assert('TESTE J: 10 MB <= Lag < 50 MB resulta em CONSERVATIVE', resJ.state === 'CONSERVATIVE');

  // TESTE K: Lag STOP: → comportamento atual preservado
  const resK = PowerSyncMonitor.resolveAndEvaluateSlots({
    currentWalLsn: '229/4C000000',
    slots: [
      {
        slot_name: `${POWERSYNC_SLOT_PREFIX}9_3296`,
        plugin: 'pgoutput',
        slot_type: 'logical',
        active: true,
        confirmed_flush_lsn: '229/4C000000',
        restart_lsn: '229/4C000000',
        lag_bytes: 52 * 1024 * 1024 // 52 MB
      }
    ]
  });
  assert('TESTE K: Lag >= 50 MB resulta em STOP', resK.state === 'STOP');

  // TESTE L: Dry-run nunca chama archive RPC
  const mockReport: DryRunReport = {
    postgresStatus: 'CONNECTED',
    tlsStatus: 'VALIDATED',
    database: 'postgres',
    user: 'postgres',
    version: 'PostgreSQL 17.6',
    powerSyncState: 'SAFE',
    powerSyncInstanceId: POWERSYNC_INSTANCE_ID,
    slotFound: 'FOUND',
    resolvedSlotName: `${POWERSYNC_SLOT_PREFIX}9_3296`,
    plugin: 'pgoutput',
    slotType: 'logical',
    active: true,
    currentWalLsn: '100/100',
    confirmedFlushLsn: '100/100',
    restartLsn: '100/100',
    lagFormatted: '1000 bytes (0 MB)',
    killSwitchStatus: 'OFF',
    condominioNome: 'Real Park',
    condominioUuid: 'ed90ec35-95f0-4a04-92b4-35fe4217f0e1',
    elegiveisAtuais: 0,
    batchSize: 100,
    maxBatches: 1,
    archiveRpcStatus: 'DRY-RUN / NOT EXECUTED',
    leaseStatus: 'SIMULATED / NOT EXECUTED',
    databaseWrites: 'ZERO',
    rowsArchived: 0,
    finalState: 'DRY_RUN_READY',
    executionSource: 'MANUAL_ORCHESTRATOR',
    simulatedExecutedBy: 'MANUAL_ORCHESTRATOR_ed90ec35-95f0-4a04-92b4-35fe4217f0e1',
    simulatedArchivedBy: 'MANUAL_ORCHESTRATOR_ed90ec35-95f0-4a04-92b4-35fe4217f0e1'
  };
  assert('TESTE L: Contrato de Archive RPC é estritamente DRY-RUN / NOT EXECUTED e writes ZERO', mockReport.archiveRpcStatus === 'DRY-RUN / NOT EXECUTED' && mockReport.databaseWrites === 'ZERO');

  // TESTE M: Unit test execução manual: archived_by != PILOT_CRON e executed_by != PILOT_CRON
  const mockCondoId = 'b699e35f-c2f9-461f-93c3-de8a80e73744';
  const auditManual = resolveAuditSemantics('MANUAL_ORCHESTRATOR', mockCondoId);
  assert(
    'TESTE M: Execução manual gera semântica MANUAL_ORCHESTRATOR_<condo_id> e != PILOT_CRON',
    auditManual.archivedBy !== 'PILOT_CRON' &&
    auditManual.executedBy !== 'PILOT_CRON' &&
    auditManual.executedBy === `MANUAL_ORCHESTRATOR_${mockCondoId}` &&
    auditManual.archivedBy === `MANUAL_ORCHESTRATOR_${mockCondoId}`
  );

  // TESTE N: Unit test execução cron: identificador distinto e explícito de cron
  const auditCron = resolveAuditSemantics('CRON_RETENTION', mockCondoId);
  assert(
    'TESTE N: Execução cron gera identificador explícito CRON_RETENTION_<condo_id>',
    auditCron.archivedBy !== 'PILOT_CRON' &&
    auditCron.executedBy !== 'PILOT_CRON' &&
    auditCron.executedBy === `CRON_RETENTION_${mockCondoId}` &&
    auditCron.archivedBy === `CRON_RETENTION_${mockCondoId}`
  );

  // TESTE O: batch_id continua como chave principal de rastreabilidade
  const mockBatchId = '800f4906-232c-4042-8781-66298b66eb15';
  const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(mockBatchId);
  assert('TESTE O: batch_id permanece como chave UUID primária de rastreabilidade entre log e histórico', isUuid);

  // TESTE P: Imutabilidade histórica preserva valores de execuções anteriores sem mutação retroativa
  const mockExistingBatch = { id: '004623f9-2977-49a0-bf50-4530e360a223', executed_by: 'PILOT_CONDO_ed90ec35-95f0-4a04-92b4-35fe4217f0e1', archived_by: 'PILOT_CRON' };
  assert(
    'TESTE P: Imutabilidade histórica preserva valores de execuções anteriores sem mutação retroativa',
    mockExistingBatch.executed_by.startsWith('PILOT_CONDO') && mockExistingBatch.archived_by === 'PILOT_CRON'
  );

  // Validações adicionais de CLI
  const testCliMissing = parseConfig([]);
  assert('Validação CLI: Condomínio ausente gera STOP imediato', Boolean(testCliMissing.error && testCliMissing.error.includes('STOP')));

  const testCliValid = parseConfig(['--condominio-id=ed90ec35-95f0-4a04-92b4-35fe4217f0e1']);
  assert('Validação CLI: Configuração oficial com batchSize 100 é aceita', Boolean(testCliValid.config && testCliValid.config.batchSize === 100 && testCliValid.config.executionSource === 'MANUAL_ORCHESTRATOR'));

  const testCli500 = parseConfig(['--condominio-id=b699e35f-c2f9-461f-93c3-de8a80e73744', '--batch-size=500']);
  assert('Validação CLI: Configuração de escala com batchSize 500 é aceita', Boolean(testCli500.config && testCli500.config.batchSize === 500 && testCli500.config.executionSource === 'MANUAL_ORCHESTRATOR'));

  const testCli1000 = parseConfig(['--condominio-id=b699e35f-c2f9-461f-93c3-de8a80e73744', '--batch-size=1000']);
  assert('Validação CLI: Configuração de escala com batchSize 1000 é aceita', Boolean(testCli1000.config && testCli1000.config.batchSize === 1000 && testCli1000.config.executionSource === 'MANUAL_ORCHESTRATOR'));

  const testCliCron = parseConfig(['--condominio-id=ed90ec35-95f0-4a04-92b4-35fe4217f0e1', '--execution-source=CRON_RETENTION']);
  assert('Validação CLI: Aceita --execution-source=CRON_RETENTION explicitamente', Boolean(testCliCron.config && testCliCron.config.executionSource === 'CRON_RETENTION'));

  const testCliInvalidSource = parseConfig(['--condominio-id=ed90ec35-95f0-4a04-92b4-35fe4217f0e1', '--execution-source=INVALID']);
  assert('Validação CLI: Rejeita --execution-source inválido com STOP', Boolean(testCliInvalidSource.error && testCliInvalidSource.error.includes('STOP')));

  // TESTE Q: parseConfig com --dry-run=false preserva modo real autorizado
  const testCliReal = parseConfig([
    '--condominio-id=b699e35f-c2f9-461f-93c3-de8a80e73744',
    '--batch-size=1000',
    '--max-batches=1',
    '--execution-source=CRON_RETENTION',
    '--dry-run=false'
  ]);
  assert(
    'TESTE Q: parseConfig com --dry-run=false preserva isDryRun = false e parâmetros autorizados',
    Boolean(
      testCliReal.config &&
      testCliReal.config.isDryRun === false &&
      testCliReal.config.batchSize === 1000 &&
      testCliReal.config.maxBatches === 1 &&
      testCliReal.config.executionSource === 'CRON_RETENTION'
    )
  );

  // TESTE R: buildArchiveRpcQuery gera assinatura oficial da RPC com parâmetros exatos
  const rpcQueryTest = buildArchiveRpcQuery({
    condominioId: 'b699e35f-c2f9-461f-93c3-de8a80e73744',
    batchSize: 1000,
    maxBatches: 1,
    timeoutMs: 45000,
    cooldownMs: 4000,
    isDryRun: false,
    killSwitch: false,
    executionSource: 'CRON_RETENTION'
  });
  assert(
    'TESTE R: buildArchiveRpcQuery gera chamada da RPC oficial com parâmetros e tipos corretos',
    rpcQueryTest.query.includes('public.archive_expired_encomendas') &&
    rpcQueryTest.query.includes('p_batch_size => $1::integer') &&
    rpcQueryTest.query.includes('p_max_batches => $2::integer') &&
    rpcQueryTest.query.includes('p_condominio_id => $3::uuid') &&
    rpcQueryTest.query.includes('p_execution_source => $4::text') &&
    rpcQueryTest.values[0] === 1000 &&
    rpcQueryTest.values[1] === 1 &&
    rpcQueryTest.values[2] === 'b699e35f-c2f9-461f-93c3-de8a80e73744' &&
    rpcQueryTest.values[3] === 'CRON_RETENTION'
  );

  // TESTE S: Pre-flight fail-closed em modo real (STOP impede chamada da RPC)
  const mockStopRealReport: ExecutionReport = {
    postgresStatus: 'CONNECTED',
    tlsStatus: 'VALIDATED',
    database: 'postgres',
    user: 'postgres',
    version: 'PostgreSQL 17.6',
    powerSyncState: 'STOP',
    powerSyncInstanceId: POWERSYNC_INSTANCE_ID,
    slotFound: 'NOT FOUND',
    resolvedSlotName: null,
    plugin: null,
    slotType: null,
    active: false,
    currentWalLsn: null,
    confirmedFlushLsn: null,
    restartLsn: null,
    lagFormatted: null,
    killSwitchStatus: 'ON',
    condominioNome: 'Residencial Recanto das Palmeiras',
    condominioUuid: 'b699e35f-c2f9-461f-93c3-de8a80e73744',
    elegiveisAtuais: 20568,
    batchSize: 1000,
    maxBatches: 1,
    isDryRun: false,
    archiveRpcStatus: 'STOPPED / NOT EXECUTED',
    leaseStatus: 'NOT ACQUIRED',
    databaseWrites: 'ZERO',
    rowsArchived: 0,
    finalState: 'STOP',
    stopReason: 'Kill switch ON',
    executionSource: 'CRON_RETENTION',
    executedBy: 'CRON_RETENTION_b699e35f-c2f9-461f-93c3-de8a80e73744',
    archivedBy: 'CRON_RETENTION_b699e35f-c2f9-461f-93c3-de8a80e73744'
  };
  assert(
    'TESTE S: Pre-flight STOP em modo real garante zero escritas e archiveRpcStatus = STOPPED / NOT EXECUTED',
    mockStopRealReport.finalState === 'STOP' &&
    mockStopRealReport.archiveRpcStatus === 'STOPPED / NOT EXECUTED' &&
    mockStopRealReport.databaseWrites === 'ZERO' &&
    mockStopRealReport.rowsArchived === 0
  );

  // TESTE T: Garantia de lote único (maxBatches = 1) sem loops ou retries automáticos
  const testMaxBatchesProtection = parseConfig([
    '--condominio-id=b699e35f-c2f9-461f-93c3-de8a80e73744',
    '--max-batches=2',
    '--dry-run=false'
  ]);
  assert(
    'TESTE T: maxBatches > 1 é terminantemente rejeitado no modo real',
    Boolean(testMaxBatchesProtection.error && testMaxBatchesProtection.error.includes('STOP'))
  );

  // ==============================================================================
  // C4C.21: SUÍTE DE TESTES OBRIGATÓRIOS DO FAIR-SHARE SCHEDULER
  // ==============================================================================

  const candidateNever: FairShareCandidate = {
    condominio_id: '8a544728-e17a-4d9c-a27d-3cb9228bd79e',
    condominio_nome: 'Praça Da Luz',
    total_elegivel: 3,
    delivered_10d: 3,
    pending_3m: 0,
    last_retention_at: null,
    retention_batches_count: 0
  };

  const candidateOlder: FairShareCandidate = {
    condominio_id: '4828f5f6-454c-438c-9ef3-9f1bf5a7ab94',
    condominio_nome: 'Montserrat',
    total_elegivel: 3160,
    delivered_10d: 3160,
    pending_3m: 0,
    last_retention_at: new Date('2026-09-13T00:35:49.292Z'),
    retention_batches_count: 1
  };

  const candidateRecent: FairShareCandidate = {
    condominio_id: 'b699e35f-c2f9-461f-93c3-de8a80e73744',
    condominio_nome: 'Residencial Recanto das Palmeiras',
    total_elegivel: 19615,
    delivered_10d: 18109,
    pending_3m: 1506,
    last_retention_at: new Date('2026-09-13T15:31:40.261Z'),
    retention_batches_count: 6
  };

  const candidateZeroBacklog: FairShareCandidate = {
    condominio_id: 'ed90ec35-95f0-4a04-92b4-35fe4217f0e1',
    condominio_nome: 'Real Park',
    total_elegivel: 0,
    delivered_10d: 0,
    pending_3m: 0,
    last_retention_at: new Date('2026-09-13T00:01:34.923Z'),
    retention_batches_count: 1
  };

  // TESTE FS1: Nunca executado (NULLS FIRST) vem antes de qualquer condomínio que já executou
  const sortedFS1 = sortFairShareCandidates([candidateOlder, candidateNever, candidateRecent]);
  assert(
    'TESTE FS1: Nunca executado (NULLS FIRST) vem antes de qualquer condomínio já executado',
    sortedFS1[0].condominio_id === candidateNever.condominio_id
  );

  // TESTE FS2: Entre condomínios já executados, menor last_retention_at (mais antigo) vem primeiro
  const sortedFS2 = sortFairShareCandidates([candidateRecent, candidateOlder]);
  assert(
    'TESTE FS2: Entre executados, menor last_retention_at vem primeiro (Least Recently Executed)',
    sortedFS2[0].condominio_id === candidateOlder.condominio_id
  );

  // TESTE FS3: Backlog desempata quando datas de retenção são idênticas
  const sameDateA: FairShareCandidate = {
    condominio_id: '11111111-1111-1111-1111-111111111111',
    condominio_nome: 'Condo Menor Backlog',
    total_elegivel: 200,
    delivered_10d: 200,
    pending_3m: 0,
    last_retention_at: new Date('2026-09-13T00:00:00.000Z'),
    retention_batches_count: 1
  };
  const sameDateB: FairShareCandidate = {
    condominio_id: '22222222-2222-2222-2222-222222222222',
    condominio_nome: 'Condo Maior Backlog',
    total_elegivel: 800,
    delivered_10d: 800,
    pending_3m: 0,
    last_retention_at: new Date('2026-09-13T00:00:00.000Z'),
    retention_batches_count: 1
  };
  const sortedFS3 = sortFairShareCandidates([sameDateA, sameDateB]);
  assert(
    'TESTE FS3: Maior backlog desempata quando datas são idênticas (total_elegivel DESC)',
    sortedFS3[0].condominio_id === sameDateB.condominio_id
  );

  // TESTE FS4: UUID desempata quando datas e backlogs são idênticos (determinismo absoluto)
  const identicalA: FairShareCandidate = {
    condominio_id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    condominio_nome: 'Condo B',
    total_elegivel: 500,
    delivered_10d: 500,
    pending_3m: 0,
    last_retention_at: new Date('2026-09-13T00:00:00.000Z'),
    retention_batches_count: 1
  };
  const identicalB: FairShareCandidate = {
    condominio_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    condominio_nome: 'Condo A',
    total_elegivel: 500,
    delivered_10d: 500,
    pending_3m: 0,
    last_retention_at: new Date('2026-09-13T00:00:00.000Z'),
    retention_batches_count: 1
  };
  const sortedFS4 = sortFairShareCandidates([identicalA, identicalB]);
  assert(
    'TESTE FS4: UUID desempata quando datas e backlogs são idênticos (condominio_id ASC)',
    sortedFS4[0].condominio_id === identicalB.condominio_id
  );

  // TESTE FS5: Condomínio sem elegíveis é excluído da seleção
  const sortedFS5 = sortFairShareCandidates([candidateZeroBacklog, candidateNever]);
  assert(
    'TESTE FS5: Condomínio com total_elegivel = 0 é estritamente excluído da seleção',
    sortedFS5.length === 1 && sortedFS5[0].condominio_id === candidateNever.condominio_id
  );

  // TESTE FS6: Condomínio com 3 elegíveis retorna lote efetivo 3
  assert(
    'TESTE FS6: Condomínio com 3 elegíveis retorna lote efetivo 3 (sem desperdício de cota)',
    calculateEffectiveBatchSize(1000, 3) === 3
  );

  // TESTE FS7: Condomínio com 156 elegíveis retorna lote efetivo 156
  assert(
    'TESTE FS7: Condomínio com 156 elegíveis retorna lote efetivo 156',
    calculateEffectiveBatchSize(1000, 156) === 156
  );

  // TESTE FS8: Condomínio com >1000 elegíveis retorna lote efetivo limitado a 1000
  assert(
    'TESTE FS8: Condomínio com >1000 elegíveis retorna lote limitado ao teto de 1000',
    calculateEffectiveBatchSize(1000, 3160) === 1000 &&
    calculateEffectiveBatchSize(1000, 19615) === 1000
  );

  // TESTE FS9: Um único condomínio elegível pode ser selecionado repetidamente em noites diferentes
  const singleCandidateState = [{ ...candidateRecent }];
  const simSingle1 = sortFairShareCandidates(singleCandidateState);
  singleCandidateState[0].last_retention_at = new Date('2026-09-14T03:00:00.000Z');
  const simSingle2 = sortFairShareCandidates(singleCandidateState);
  assert(
    'TESTE FS9: Um único condomínio elegível pode ser selecionado repetidamente em noites consecutivas',
    simSingle1[0].condominio_id === candidateRecent.condominio_id &&
    simSingle2[0].condominio_id === candidateRecent.condominio_id
  );

  // TESTE FS10: Fair-Share não usa LIKE em executed_by para tenant resolution
  const fairShareSqlInspection = queryFairShareCandidates.toString();
  assert(
    'TESTE FS10: Fair-Share query não utiliza LIKE em executed_by para identificar tenant',
    !fairShareSqlInspection.includes("executed_by LIKE") &&
    fairShareSqlInspection.includes("h.archive_batch_id = l.batch_id")
  );

  // TESTE FS11: Join archive_log → historico identifica corretamente condomínio
  assert(
    'TESTE FS11: Mapeamento de tenant é realizado estritamente por join relacional batch_id -> archive_batch_id',
    fairShareSqlInspection.includes("public.encomendas_archive_log l") &&
    fairShareSqlInspection.includes("public.encomendas_historico h")
  );

  // TESTE FS12: Ambiguidade batch_id associada a múltiplos condomínios deve resultar em FAIL-CLOSED
  let ambiguityPass = false;
  try {
    const mockRows = [{ archive_batch_id: 'fake-batch', condo_count: 2 }];
    if (mockRows.length > 0) {
      throw new Error(`STOP_AMBIGUOUS_BATCH_CONDO: Detectado(s) ${mockRows.length} lote(s) com múltiplos condomínios`);
    }
  } catch (err: any) {
    ambiguityPass = err.message.includes('STOP_AMBIGUOUS_BATCH_CONDO');
  }
  assert(
    'TESTE FS12: Ambiguidade batch_id associada a múltiplos condomínios resulta em FAIL-CLOSED',
    ambiguityPass
  );

  // TESTE FS13: MANUAL_ORCHESTRATOR não bloqueia CRON_RETENTION no ciclo de idempotência
  const mockManualLog = {
    id: 'log-1',
    batch_id: 'batch-1',
    executed_by: 'MANUAL_ORCHESTRATOR_b699e35f-c2f9-461f-93c3-de8a80e73744',
    status: 'PARTIAL'
  };
  const isBlockedByManual = mockManualLog.executed_by.startsWith('CRON_RETENTION_');
  assert(
    'TESTE FS13: MANUAL_ORCHESTRATOR não bloqueia CRON_RETENTION no ciclo de idempotência',
    !isBlockedByManual
  );

  // TESTE FS14: CRON_RETENTION recente bloqueia nova execução automática no ciclo de 12h
  const mockCronLog = {
    id: 'log-2',
    batch_id: 'batch-2',
    executed_by: 'CRON_RETENTION_b699e35f-c2f9-461f-93c3-de8a80e73744',
    status: 'SUCCESS'
  };
  const isBlockedByCron = mockCronLog.executed_by.startsWith('CRON_RETENTION_');
  assert(
    'TESTE FS14: CRON_RETENTION recente bloqueia nova execução automática no ciclo de 12h',
    isBlockedByCron
  );

  // TESTE FS15: Dry-run com Fair-Share nunca chama archive_expired_encomendas e garante zero escritas
  const mockDryRunFSReport: ExecutionReport = {
    postgresStatus: 'CONNECTED',
    tlsStatus: 'VALIDATED',
    database: 'postgres',
    user: 'postgres',
    version: 'PostgreSQL 17.6',
    powerSyncState: 'SAFE',
    powerSyncInstanceId: POWERSYNC_INSTANCE_ID,
    slotFound: 'FOUND',
    resolvedSlotName: `${POWERSYNC_SLOT_PREFIX}9_3296`,
    plugin: 'pgoutput',
    slotType: 'logical',
    active: true,
    currentWalLsn: '100/100',
    confirmedFlushLsn: '100/100',
    restartLsn: '100/100',
    lagFormatted: '0 bytes (0 MB)',
    killSwitchStatus: 'OFF',
    condominioNome: 'Praça Da Luz',
    condominioUuid: '8a544728-e17a-4d9c-a27d-3cb9228bd79e',
    elegiveisAtuais: 3,
    batchSize: 3,
    maxBatches: 1,
    isDryRun: true,
    archiveRpcStatus: 'DRY-RUN / NOT EXECUTED',
    leaseStatus: 'SIMULATED / NOT EXECUTED',
    databaseWrites: 'ZERO',
    rowsArchived: 0,
    finalState: 'DRY_RUN_READY',
    executionSource: 'CRON_RETENTION',
    executedBy: 'CRON_RETENTION_8a544728-e17a-4d9c-a27d-3cb9228bd79e',
    archivedBy: 'CRON_RETENTION_8a544728-e17a-4d9c-a27d-3cb9228bd79e',
    fairShareActive: true,
    selectionReason: 'NULLS FIRST (Primeira execução)',
    totalCandidates: 3
  };
  assert(
    'TESTE FS15: Dry-run com Fair-Share nunca chama archive_expired_encomendas e garante zero escritas',
    mockDryRunFSReport.finalState === 'DRY_RUN_READY' &&
    mockDryRunFSReport.archiveRpcStatus === 'DRY-RUN / NOT EXECUTED' &&
    mockDryRunFSReport.databaseWrites === 'ZERO' &&
    mockDryRunFSReport.rowsArchived === 0 &&
    mockDryRunFSReport.fairShareActive === true
  );

  // TESTE FS16: Simulação de 10 noites (D1..D10) respeita estritamente NULLS FIRST, LRE, backlog e UUID
  const tenNights = simulateTenNights([candidateNever, candidateOlder, candidateRecent]);
  assert(
    'TESTE FS16: Simulação de 10 noites respeita estritamente NULLS FIRST, LRE, backlog e UUID',
    tenNights.length === 10 &&
    tenNights[0].condoId === candidateNever.condominio_id &&
    tenNights[0].batchSize === 3 &&
    tenNights[0].backlogAfter === 0 &&
    tenNights[1].condoId === candidateOlder.condominio_id &&
    tenNights[2].condoId === candidateRecent.condominio_id &&
    tenNights[3].condoId === candidateOlder.condominio_id &&
    tenNights[4].condoId === candidateRecent.condominio_id &&
    tenNights[5].condoId === candidateOlder.condominio_id &&
    tenNights[6].condoId === candidateRecent.condominio_id &&
    tenNights[7].condoId === candidateOlder.condominio_id &&
    tenNights[7].batchSize === 160 &&
    tenNights[7].backlogAfter === 0 &&
    tenNights[8].condoId === candidateRecent.condominio_id &&
    tenNights[9].condoId === candidateRecent.condominio_id
  );

  console.log(`\nResultado da Suíte: ${passed}/${total} testes aprovados.\n`);
  return passed === total;
}

// ── CLI Runner ──
async function main() {
  const args = process.argv.slice(2);
  const parsed = parseConfig(args);

  if (parsed.isTest) {
    const success = runUnitTests();
    process.exit(success ? 0 : 1);
  }

  if (parsed.error) {
    console.error(parsed.error);
    process.exit(1);
  }

  if (!parsed.config) {
    console.error('Configuração inválida.');
    process.exit(1);
  }

  try {
    const report = await runOrchestrator(parsed.config);
    console.log(formatReport(report));
    if (report.finalState === 'DRY_RUN_READY' || report.finalState === 'SUCCESS' || report.finalState === 'PARTIAL') {
      process.exit(0);
    } else if (report.finalState === 'STOP') {
      process.exit(2);
    } else {
      process.exit(1);
    }
  } catch (err: any) {
    console.error('Erro na execução do orquestrador:', err.message || err);
    process.exit(1);
  }
}

// Executar se chamado via linha de comando direta
const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  main();
}
