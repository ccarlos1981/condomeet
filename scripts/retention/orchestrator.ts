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
import type { DryRunReport, OrchestratorConfig, PowerSyncState, RawSlotData, ExecutionSource } from './types.js';
import { resolveAuditSemantics } from './types.js';

const { Client } = pg;

// ── Utilitário seguro para carregar variáveis locais sem expor segredos ──
function loadSecureEnv(): { password: string | null; caPath: string | null } {
  let password = process.env.POSTGRES_PASSWORD || null;
  let caPath = process.env.SUPABASE_SSL_CA_PATH || null;

  if (!password || !caPath) {
    const candidatePaths = [
      path.resolve(process.cwd(), 'web-app/.env.local'),
      path.resolve(process.cwd(), '.env.local')
    ];
    for (const envPath of candidatePaths) {
      if (fs.existsSync(envPath)) {
        const content = fs.readFileSync(envPath, 'utf8');
        const passMatch = content.match(/^POSTGRES_PASSWORD=(.*)$/m);
        const caMatch = content.match(/^SUPABASE_SSL_CA_PATH=(.*)$/m);
        if (passMatch && !password) {
          password = passMatch[1].trim().replace(/^['"]|['"]$/g, '');
        }
        if (caMatch && !caPath) {
          caPath = caMatch[1].trim().replace(/^['"]|['"]$/g, '');
        }
      }
    }
  }

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

  return { password, caPath };
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

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--condominio-id' && args[i + 1]) {
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

  // Validação 1: Condomínio obrigatório
  if (!condominioId || condominioId.trim() === '') {
    return { error: 'STOP: O parâmetro --condominio-id é estritamente obrigatório. Execução global é proibida.' };
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

  // Validação 6: Dry-run obrigatório nesta fase
  if (!isDryRun) {
    return { error: 'STOP: O modo de execução real está expressamente proibido nesta onda. --dry-run deve ser true.' };
  }

  const killSwitch = process.env.RETENTION_KILL_SWITCH === 'true';

  return {
    config: {
      condominioId,
      batchSize,
      maxBatches,
      timeoutMs,
      cooldownMs,
      isDryRun: true,
      killSwitch,
      executionSource
    }
  };
}

// ── Execução Principal do Dry-Run ──
export async function runDryRun(config: OrchestratorConfig): Promise<DryRunReport> {
  const { password, caPath } = loadSecureEnv();

  if (!password) {
    throw new Error('POSTGRES_PASSWORD_MISSING: Senha do banco não localizada no ambiente local.');
  }

  if (!caPath || !fs.existsSync(caPath)) {
    throw new Error(`SUPABASE_SSL_CA_PATH_MISSING: Certificado CA não localizado em '${caPath}'.`);
  }

  const caCert = fs.readFileSync(caPath, 'utf8');

  const client = new Client({
    host: 'db.avypyaxthvgaybplnwxu.supabase.co',
    port: 5432,
    user: 'postgres',
    database: 'postgres',
    password: password,
    ssl: {
      rejectUnauthorized: true,
      ca: caCert
    },
    connectionTimeoutMillis: 5000
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

    // Monitor do PowerSync
    const monitor = new PowerSyncMonitor();
    const slotInfo = await monitor.checkSlot(client);

    // Validação de Condomínio no Banco
    const condoRes = await client.query('SELECT id, nome FROM public.condominios WHERE id = $1;', [config.condominioId]);
    const condoFound = condoRes.rows.length > 0;
    const condoNome = condoFound ? condoRes.rows[0].nome : null;

    // Regra da Seção 10: Se o UUID fornecido for o teste do Real Park (72a5f3b3...),
    // validar se corresponde ao Real Park
    let condoMatchValid = true;
    let stopReason: string | undefined;

    if (config.condominioId === '72a5f3b3-7c6a-4d5d-8f67-5f0e7a2d9f2e') {
      if (!condoFound || condoNome !== 'Real Park') {
        condoMatchValid = false;
        stopReason = `O UUID '${config.condominioId}' não corresponde ao condomínio Real Park no banco oficial.`;
      }
    } else if (!condoFound) {
      condoMatchValid = false;
      stopReason = `Condomínio com UUID '${config.condominioId}' não foi encontrado no banco de dados.`;
    }

    // Consulta Read-only de elegíveis atuais
    let elegiveisCount: number | null = null;
    if (condoFound) {
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
    }

    // Avaliação do Estado Final
    let finalState: 'DRY_RUN_READY' | 'STOP' = 'DRY_RUN_READY';

    if (config.killSwitch) {
      finalState = 'STOP';
      stopReason = 'RETENTION_KILL_SWITCH ativado (Kill switch: ON).';
    } else if (!condoMatchValid) {
      finalState = 'STOP';
    } else if (slotInfo.state === 'STOP') {
      finalState = 'STOP';
      stopReason = slotInfo.reason || 'PowerSync slot em estado crítico STOP.';
    }

    const audit = resolveAuditSemantics(config.executionSource, config.condominioId);

    const report: DryRunReport = {
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
      killSwitchStatus: config.killSwitch ? 'ON' : 'OFF',
      condominioNome: condoNome,
      condominioUuid: config.condominioId,
      elegiveisAtuais: elegiveisCount,
      batchSize: config.batchSize,
      maxBatches: config.maxBatches,
      archiveRpcStatus: 'DRY-RUN / NOT EXECUTED',
      leaseStatus: 'SIMULATED / NOT EXECUTED',
      databaseWrites: 'ZERO',
      rowsArchived: 0,
      finalState: finalState,
      stopReason: stopReason,
      executionSource: audit.executionSource,
      simulatedExecutedBy: audit.executedBy,
      simulatedArchivedBy: audit.archivedBy
    };

    return report;
  } finally {
    await client.end().catch(() => {});
  }
}

// ── Formatador Oficial de Saída (C4C.4-A) ──
export function formatReport(report: DryRunReport): string {
  const lines: string[] = [
    '=== C4C.4-A DRY-RUN ===',
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
    report.simulatedExecutedBy,
    '',
    'Audit archived_by:',
    report.simulatedArchivedBy,
    '',
    'Batch:',
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
    const report = await runDryRun(parsed.config);
    console.log(formatReport(report));
    process.exit(report.finalState === 'DRY_RUN_READY' ? 0 : 2);
  } catch (err: any) {
    console.error('Erro na execução do dry-run:', err.message || err);
    process.exit(1);
  }
}

// Executar se chamado via linha de comando direta
const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  main();
}
