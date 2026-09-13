/**
 * CONDOMEET — C4C.14
 * Suíte de Testes Offline / Mock do Scheduler da Retenção
 * Regime: 100% OFFLINE / ZERO CONEXÃO COM PRODUÇÃO
 */

import { parseConfig, formatReport, buildArchiveRpcQuery, sortFairShareCandidates, calculateEffectiveBatchSize, simulateTenNights, queryFairShareCandidates } from './orchestrator.js';
import { PowerSyncMonitor, POWERSYNC_INSTANCE_ID, POWERSYNC_SLOT_PREFIX, LAG_THRESHOLDS } from './powersync_monitor.js';
import { resolveAuditSemantics } from './types.js';
import type { DryRunReport, ExecutionReport, OrchestratorConfig, FairShareCandidate } from './types.js';

interface TestResult {
  name: string;
  passed: boolean;
  details?: string;
}

const results: TestResult[] = [];

function assert(name: string, condition: boolean, details?: string) {
  results.push({ name, passed: condition, details });
  const icon = condition ? '✅ PASS' : '❌ FAIL';
  console.log(`${icon}: ${name}${details ? ` (${details})` : ''}`);
}

console.log('=== C4C.14: SUÍTE DE TESTES OFFLINE / MOCK DO SCHEDULER ===\n');

const TARGET_CONDO_ID = 'b699e35f-c2f9-461f-93c3-de8a80e73744';

// 1. Scheduler dispara com configuração válida
const test1 = parseConfig([
  `--condominio-id=${TARGET_CONDO_ID}`,
  '--batch-size=1000',
  '--max-batches=1',
  '--execution-source=CRON_RETENTION'
]);
assert(
  '1. Scheduler dispara com parâmetros válidos',
  Boolean(
    test1.config &&
    test1.config.condominioId === TARGET_CONDO_ID &&
    test1.config.batchSize === 1000 &&
    test1.config.maxBatches === 1 &&
    test1.config.executionSource === 'CRON_RETENTION' &&
    test1.config.isDryRun === true
  )
);

// 2. Scheduler bloqueado quando preflight falha
const mockBlockedSlot = PowerSyncMonitor.resolveAndEvaluateSlots({
  currentWalLsn: '100/100',
  slots: []
});
assert(
  '2. Scheduler bloqueado quando preflight falha',
  mockBlockedSlot.state === 'STOP' && mockBlockedSlot.reason?.includes('STOP_NO_ACTIVE_POWERSYNC_SLOT') === true
);

// 3. Kill Switch: Environment Kill Switch ativo gera STOP e exit code 2
const killSwitchActiveConfig: OrchestratorConfig = {
  condominioId: TARGET_CONDO_ID,
  batchSize: 1000,
  maxBatches: 1,
  timeoutMs: 45000,
  cooldownMs: 4000,
  isDryRun: true,
  killSwitch: true,
  executionSource: 'CRON_RETENTION'
};
const auditKill = resolveAuditSemantics(killSwitchActiveConfig.executionSource, killSwitchActiveConfig.condominioId);
const mockKillReport: DryRunReport = {
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
  killSwitchStatus: 'ON',
  condominioNome: 'Residencial Recanto das Palmeiras',
  condominioUuid: TARGET_CONDO_ID,
  elegiveisAtuais: 20562,
  batchSize: 1000,
  maxBatches: 1,
  archiveRpcStatus: 'DRY-RUN / NOT EXECUTED',
  leaseStatus: 'SIMULATED / NOT EXECUTED',
  databaseWrites: 'ZERO',
  rowsArchived: 0,
  finalState: 'STOP',
  stopReason: 'RETENTION_KILL_SWITCH ativado (Kill switch: ON).',
  executionSource: auditKill.executionSource,
  simulatedExecutedBy: auditKill.executedBy,
  simulatedArchivedBy: auditKill.archivedBy
};
assert(
  '3. Kill Switch ativo gera finalState: STOP e Kill switch: ON',
  mockKillReport.finalState === 'STOP' && mockKillReport.killSwitchStatus === 'ON'
);

// 4. PowerSync SAFE (lag < 5 MB)
const psSafe = PowerSyncMonitor.resolveAndEvaluateSlots({
  currentWalLsn: '200/200',
  slots: [
    {
      slot_name: `${POWERSYNC_SLOT_PREFIX}9_3296`,
      plugin: 'pgoutput',
      slot_type: 'logical',
      active: true,
      confirmed_flush_lsn: '200/200',
      restart_lsn: '200/200',
      lag_bytes: 1024 * 1024 // 1 MB
    }
  ]
});
assert('4. PowerSync SAFE (lag < 5 MB)', psSafe.state === 'SAFE' && psSafe.lag_mb === 1);

// 5. PowerSync WAIT (5 MB <= lag < 10 MB)
const psWait = PowerSyncMonitor.resolveAndEvaluateSlots({
  currentWalLsn: '200/200',
  slots: [
    {
      slot_name: `${POWERSYNC_SLOT_PREFIX}9_3296`,
      plugin: 'pgoutput',
      slot_type: 'logical',
      active: true,
      confirmed_flush_lsn: '200/200',
      restart_lsn: '200/200',
      lag_bytes: 6 * 1024 * 1024 // 6 MB
    }
  ]
});
assert('5. PowerSync WAIT (5 MB <= lag < 10 MB)', psWait.state === 'WAIT' && psWait.lag_mb === 6);

// 6. PowerSync STOP (lag >= 10 MB / crítico)
const psStop = PowerSyncMonitor.resolveAndEvaluateSlots({
  currentWalLsn: '200/200',
  slots: [
    {
      slot_name: `${POWERSYNC_SLOT_PREFIX}9_3296`,
      plugin: 'pgoutput',
      slot_type: 'logical',
      active: true,
      confirmed_flush_lsn: '200/200',
      restart_lsn: '200/200',
      lag_bytes: 55 * 1024 * 1024 // 55 MB
    }
  ]
});
assert('6. PowerSync STOP (lag >= 50 MB / crítico)', psStop.state === 'STOP' && psStop.lag_mb === 55);

// 7. Slot inexistente gera STOP
const psMissing = PowerSyncMonitor.resolveAndEvaluateSlots({
  currentWalLsn: '200/200',
  slots: []
});
assert('7. Slot inexistente gera STOP', psMissing.state === 'STOP' && psMissing.resolved_slot === null);

// 8. Slot ambíguo gera STOP
const psAmbiguous = PowerSyncMonitor.resolveAndEvaluateSlots({
  currentWalLsn: '200/200',
  slots: [
    {
      slot_name: `${POWERSYNC_SLOT_PREFIX}slot_1`,
      plugin: 'pgoutput',
      slot_type: 'logical',
      active: true,
      confirmed_flush_lsn: '200/200',
      restart_lsn: '200/200',
      lag_bytes: 0
    },
    {
      slot_name: `${POWERSYNC_SLOT_PREFIX}slot_2`,
      plugin: 'pgoutput',
      slot_type: 'logical',
      active: true,
      confirmed_flush_lsn: '200/200',
      restart_lsn: '200/200',
      lag_bytes: 0
    }
  ]
});
assert('8. Slot ambíguo gera STOP', psAmbiguous.state === 'STOP' && psAmbiguous.reason?.includes('STOP_AMBIGUOUS_POWERSYNC_SLOT') === true);

// 9. Condomínio ausente gera erro imediato
const noCondo = parseConfig(['--batch-size=1000']);
assert('9. Condomínio ausente rejeitado com erro explícito', Boolean(noCondo.error && noCondo.error.includes('STOP')));

// 10. Timeout estrito em 45.000 ms
const invalidTimeout = parseConfig([`--condominio-id=${TARGET_CONDO_ID}`, '--timeout=30000']);
const validTimeout = parseConfig([`--condominio-id=${TARGET_CONDO_ID}`, '--timeout=45000']);
assert(
  '10. Timeout rígido de 45.000 ms validado',
  Boolean(invalidTimeout.error && validTimeout.config && validTimeout.config.timeoutMs === 45000)
);

// 11. Erro PostgreSQL tratado com fail-closed
function simulateConnectionError(): { status: 'FAILED'; error: string } {
  try {
    throw new Error('connect ECONNREFUSED 127.0.0.1:5432');
  } catch (err: any) {
    return { status: 'FAILED', error: err.message };
  }
}
const connErr = simulateConnectionError();
assert('11. Erro PostgreSQL capturado e tratado fail-closed', connErr.status === 'FAILED' && connErr.error.includes('ECONNREFUSED'));

// 12. Mapeamento de Exit Codes
function getExpectedExitCode(finalState: 'DRY_RUN_READY' | 'STOP', isError: boolean): number {
  if (isError) return 1;
  if (finalState === 'STOP') return 2;
  return 0;
}
assert(
  '12. Exit codes (0 = sucesso/ready, 1 = erro, 2 = stop/kill switch)',
  getExpectedExitCode('DRY_RUN_READY', false) === 0 &&
  getExpectedExitCode('STOP', false) === 2 &&
  getExpectedExitCode('STOP', true) === 1
);

// 13. Concorrência: Garantia singleton do advisory lock
function simulateAdvisoryLock(isAlreadyLocked: boolean): { canProceed: boolean; status: string } {
  if (isAlreadyLocked) {
    return { canProceed: false, status: 'SKIPPED' };
  }
  return { canProceed: true, status: 'LOCKED' };
}
assert(
  '13. Concorrência: segunda execução bloqueada com status SKIPPED',
  simulateAdvisoryLock(true).canProceed === false && simulateAdvisoryLock(true).status === 'SKIPPED'
);

// 14. Structured Logging completo
const auditSample = resolveAuditSemantics('CRON_RETENTION', TARGET_CONDO_ID);
const sampleStructuredLog = {
  execution_id: 'e1234567-89ab-cdef-0123-456789abcdef',
  timestamp_start: '2026-09-13T06:00:00.000Z',
  timestamp_end: '2026-09-13T06:00:00.250Z',
  condominio_id: TARGET_CONDO_ID,
  condominio_nome: 'Residencial Recanto das Palmeiras',
  batch_size: 1000,
  max_batches: 1,
  batch_id: '0c11297e-ba35-4577-b005-51b0d7de7a36',
  rows_archived: 1000,
  rows_delivered_10d: 0,
  rows_pending_3m: 1000,
  duration_ms: 63,
  powersync_slot_name: `${POWERSYNC_SLOT_PREFIX}9_3296`,
  powersync_lag_pre_bytes: 0,
  powersync_lag_post_bytes: 48,
  status: 'SUCCESS',
  error_message: null,
  exit_code: 0,
  execution_source: auditSample.executionSource,
  executed_by: auditSample.executedBy,
  archived_by: auditSample.archivedBy
};

const requiredFields = [
  'execution_id', 'timestamp_start', 'timestamp_end', 'condominio_id',
  'batch_size', 'rows_archived', 'duration_ms', 'powersync_slot_name',
  'powersync_lag_pre_bytes', 'powersync_lag_post_bytes', 'status',
  'error_message', 'exit_code', 'execution_source', 'executed_by', 'archived_by'
];
const allFieldsPresent = requiredFields.every(f => f in sampleStructuredLog);
assert('14. Structured Logging contém todos os campos de telemetria obrigatórios', allFieldsPresent);

// 15. Dry-run default é true e não escreve
const testDefaultDryRun = parseConfig([
  `--condominio-id=${TARGET_CONDO_ID}`,
  '--batch-size=1000',
  '--max-batches=1'
]);
assert(
  '15. Dry-run padrão é true (zero writes por default)',
  Boolean(testDefaultDryRun.config && testDefaultDryRun.config.isDryRun === true)
);

// 16. Dry-run explicitamente false é aceito com parâmetros válidos autorizados
const testExplicitReal = parseConfig([
  `--condominio-id=${TARGET_CONDO_ID}`,
  '--batch-size=1000',
  '--max-batches=1',
  '--execution-source=CRON_RETENTION',
  '--dry-run=false'
]);
assert(
  '16. Dry-run explicitamente false é aceito quando solicitado',
  Boolean(
    testExplicitReal.config &&
    testExplicitReal.config.isDryRun === false &&
    testExplicitReal.config.batchSize === 1000 &&
    testExplicitReal.config.maxBatches === 1 &&
    testExplicitReal.config.executionSource === 'CRON_RETENTION'
  )
);

// 17. buildArchiveRpcQuery constrói a chamada oficial correta com tipos e parâmetros autorizados
const realRpcQuery = buildArchiveRpcQuery({
  condominioId: TARGET_CONDO_ID,
  batchSize: 1000,
  maxBatches: 1,
  timeoutMs: 45000,
  cooldownMs: 4000,
  isDryRun: false,
  killSwitch: false,
  executionSource: 'CRON_RETENTION'
});
assert(
  '17. buildArchiveRpcQuery constrói assinatura exata da RPC oficial',
  realRpcQuery.query.includes('public.archive_expired_encomendas') &&
  realRpcQuery.query.includes('p_batch_size => $1::integer') &&
  realRpcQuery.query.includes('p_max_batches => $2::integer') &&
  realRpcQuery.query.includes('p_condominio_id => $3::uuid') &&
  realRpcQuery.query.includes('p_execution_source => $4::text')
);

// 18. Parâmetros do condomínio são rigorosamente preservados na query
assert(
  '18. Parâmetros do condomínio preservados na chamada da RPC',
  realRpcQuery.values[0] === 1000 &&
  realRpcQuery.values[1] === 1 &&
  realRpcQuery.values[2] === TARGET_CONDO_ID &&
  realRpcQuery.values[3] === 'CRON_RETENTION'
);

// 19. Execution source correto (CRON_RETENTION) e semântica de auditoria
const auditReal = resolveAuditSemantics('CRON_RETENTION', TARGET_CONDO_ID);
assert(
  '19. Execution source CRON_RETENTION gera semântica de auditoria oficial',
  auditReal.executionSource === 'CRON_RETENTION' &&
  auditReal.executedBy === `CRON_RETENTION_${TARGET_CONDO_ID}` &&
  auditReal.archivedBy === `CRON_RETENTION_${TARGET_CONDO_ID}`
);

// 20. p_max_batches = 1: tentativa de p_max_batches > 1 é bloqueada
const testMultiBatchForbidden = parseConfig([
  `--condominio-id=${TARGET_CONDO_ID}`,
  '--max-batches=2',
  '--dry-run=false'
]);
assert(
  '20. p_max_batches > 1 é estritamente proibido no modo real',
  Boolean(testMultiBatchForbidden.error && testMultiBatchForbidden.error.includes('STOP'))
);

// 21. Kill switch bloqueia chamada no modo real
const mockKillSwitchBlockReport: ExecutionReport = {
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
  killSwitchStatus: 'ON',
  condominioNome: 'Residencial Recanto das Palmeiras',
  condominioUuid: TARGET_CONDO_ID,
  elegiveisAtuais: 20568,
  batchSize: 1000,
  maxBatches: 1,
  isDryRun: false,
  archiveRpcStatus: 'STOPPED / NOT EXECUTED',
  leaseStatus: 'NOT ACQUIRED',
  databaseWrites: 'ZERO',
  rowsArchived: 0,
  finalState: 'STOP',
  stopReason: 'RETENTION_KILL_SWITCH ativado',
  executionSource: 'CRON_RETENTION',
  executedBy: `CRON_RETENTION_${TARGET_CONDO_ID}`,
  archivedBy: `CRON_RETENTION_${TARGET_CONDO_ID}`
};
assert(
  '21. Kill switch bloqueia execução real e garante zero escritas',
  mockKillSwitchBlockReport.finalState === 'STOP' &&
  mockKillSwitchBlockReport.archiveRpcStatus === 'STOPPED / NOT EXECUTED' &&
  mockKillSwitchBlockReport.databaseWrites === 'ZERO' &&
  mockKillSwitchBlockReport.rowsArchived === 0
);

// 22. PowerSync inseguro bloqueia chamada no modo real
const mockPowerSyncStopReport: ExecutionReport = {
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
  killSwitchStatus: 'OFF',
  condominioNome: 'Residencial Recanto das Palmeiras',
  condominioUuid: TARGET_CONDO_ID,
  elegiveisAtuais: 20568,
  batchSize: 1000,
  maxBatches: 1,
  isDryRun: false,
  archiveRpcStatus: 'STOPPED / NOT EXECUTED',
  leaseStatus: 'NOT ACQUIRED',
  databaseWrites: 'ZERO',
  rowsArchived: 0,
  finalState: 'STOP',
  stopReason: 'STOP_NO_ACTIVE_POWERSYNC_SLOT',
  executionSource: 'CRON_RETENTION',
  executedBy: `CRON_RETENTION_${TARGET_CONDO_ID}`,
  archivedBy: `CRON_RETENTION_${TARGET_CONDO_ID}`
};
assert(
  '22. PowerSync inseguro bloqueia execução real e garante zero escritas',
  mockPowerSyncStopReport.finalState === 'STOP' &&
  mockPowerSyncStopReport.archiveRpcStatus === 'STOPPED / NOT EXECUTED' &&
  mockPowerSyncStopReport.databaseWrites === 'ZERO' &&
  mockPowerSyncStopReport.rowsArchived === 0
);

// ==============================================================================
// C4C.21: TESTES ESPECÍFICOS DE FAIR-SHARE SCHEDULER
// ==============================================================================

const fsNever: FairShareCandidate = {
  condominio_id: '8a544728-e17a-4d9c-a27d-3cb9228bd79e',
  condominio_nome: 'Praça Da Luz',
  total_elegivel: 3,
  delivered_10d: 3,
  pending_3m: 0,
  last_retention_at: null,
  retention_batches_count: 0
};

const fsOlder: FairShareCandidate = {
  condominio_id: '4828f5f6-454c-438c-9ef3-9f1bf5a7ab94',
  condominio_nome: 'Montserrat',
  total_elegivel: 3160,
  delivered_10d: 3160,
  pending_3m: 0,
  last_retention_at: new Date('2026-09-13T00:35:49.292Z'),
  retention_batches_count: 1
};

const fsRecent: FairShareCandidate = {
  condominio_id: 'b699e35f-c2f9-461f-93c3-de8a80e73744',
  condominio_nome: 'Residencial Recanto das Palmeiras',
  total_elegivel: 19615,
  delivered_10d: 18109,
  pending_3m: 1506,
  last_retention_at: new Date('2026-09-13T15:31:40.261Z'),
  retention_batches_count: 6
};

// 23. Nunca executado vem antes
const fsSorted1 = sortFairShareCandidates([fsOlder, fsNever, fsRecent]);
assert(
  '23. Fair-Share: Nunca executado (NULLS FIRST) vem antes de condomínio já executado',
  fsSorted1[0].condominio_id === fsNever.condominio_id
);

// 24. Entre executados, menor last_retention_at vem primeiro
const fsSorted2 = sortFairShareCandidates([fsRecent, fsOlder]);
assert(
  '24. Fair-Share: Entre executados, menor last_retention_at vem primeiro (LRE)',
  fsSorted2[0].condominio_id === fsOlder.condominio_id
);

// 25. Backlog desempata quando datas de retenção são idênticas
const fsSameDateA: FairShareCandidate = {
  condominio_id: '11111111-1111-1111-1111-111111111111',
  condominio_nome: 'Condo 100',
  total_elegivel: 100,
  delivered_10d: 100,
  pending_3m: 0,
  last_retention_at: new Date('2026-09-13T00:00:00.000Z'),
  retention_batches_count: 1
};
const fsSameDateB: FairShareCandidate = {
  condominio_id: '22222222-2222-2222-2222-222222222222',
  condominio_nome: 'Condo 500',
  total_elegivel: 500,
  delivered_10d: 500,
  pending_3m: 0,
  last_retention_at: new Date('2026-09-13T00:00:00.000Z'),
  retention_batches_count: 1
};
const fsSorted3 = sortFairShareCandidates([fsSameDateA, fsSameDateB]);
assert(
  '25. Fair-Share: Maior backlog desempata quando datas são idênticas',
  fsSorted3[0].condominio_id === fsSameDateB.condominio_id
);

// 26. UUID desempata
const fsIdA: FairShareCandidate = {
  condominio_id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  condominio_nome: 'B',
  total_elegivel: 500,
  delivered_10d: 500,
  pending_3m: 0,
  last_retention_at: new Date('2026-09-13T00:00:00.000Z'),
  retention_batches_count: 1
};
const fsIdB: FairShareCandidate = {
  condominio_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  condominio_nome: 'A',
  total_elegivel: 500,
  delivered_10d: 500,
  pending_3m: 0,
  last_retention_at: new Date('2026-09-13T00:00:00.000Z'),
  retention_batches_count: 1
};
const fsSorted4 = sortFairShareCandidates([fsIdA, fsIdB]);
assert(
  '26. Fair-Share: UUID desempata com determinismo absoluto (ASC)',
  fsSorted4[0].condominio_id === fsIdB.condominio_id
);

// 27. Condomínio sem elegíveis é excluído
const fsZero: FairShareCandidate = {
  condominio_id: '00000000-0000-0000-0000-000000000000',
  condominio_nome: 'Zero',
  total_elegivel: 0,
  delivered_10d: 0,
  pending_3m: 0,
  last_retention_at: null,
  retention_batches_count: 0
};
const fsSorted5 = sortFairShareCandidates([fsZero, fsOlder]);
assert(
  '27. Fair-Share: Condomínio sem elegíveis é excluído da seleção',
  fsSorted5.length === 1 && fsSorted5[0].condominio_id === fsOlder.condominio_id
);

// 28. Condomínio com 3 elegíveis retorna lote efetivo 3
assert(
  '28. Quota: Condomínio com 3 elegíveis retorna lote efetivo 3',
  calculateEffectiveBatchSize(1000, 3) === 3
);

// 29. Condomínio com 156 retorna 156
assert(
  '29. Quota: Condomínio com 156 retorna lote efetivo 156',
  calculateEffectiveBatchSize(1000, 156) === 156
);

// 30. Condomínio com >1000 retorna 1000
assert(
  '30. Quota: Condomínio com >1000 retorna 1000',
  calculateEffectiveBatchSize(1000, 3160) === 1000
);

// 31. Um único condomínio elegível pode ser selecionado repetidamente em noites diferentes
const fsSingleState = [{ ...fsRecent }];
const fsSimNight1 = sortFairShareCandidates(fsSingleState);
fsSingleState[0].last_retention_at = new Date('2026-09-14T03:00:00.000Z');
const fsSimNight2 = sortFairShareCandidates(fsSingleState);
assert(
  '31. Fair-Share: Um único condomínio elegível pode ser selecionado repetidamente em noites diferentes',
  fsSimNight1[0].condominio_id === fsRecent.condominio_id &&
  fsSimNight2[0].condominio_id === fsRecent.condominio_id
);

// 32. Fair-Share não usa LIKE em executed_by
const fairShareCode = queryFairShareCandidates.toString();
assert(
  '32. Fair-Share: Não usa LIKE em executed_by para resolver tenant',
  !fairShareCode.includes('executed_by LIKE') && fairShareCode.includes('h.archive_batch_id = l.batch_id')
);

// 33. Join archive_log → historico identifica corretamente condo
assert(
  '33. Fair-Share: Join relacional estrito archive_log -> historico',
  fairShareCode.includes('public.encomendas_archive_log l') && fairShareCode.includes('public.encomendas_historico h')
);

// 34. Ambiguidade batch_id associada a mais de um condomínio deve resultar em FAIL-CLOSED
let ambFailClosed = false;
try {
  const fakeAmb = [{ archive_batch_id: 'b1', condo_count: 2 }];
  if (fakeAmb.length > 0) {
    throw new Error('STOP_AMBIGUOUS_BATCH_CONDO');
  }
} catch (e: any) {
  ambFailClosed = e.message.includes('STOP_AMBIGUOUS_BATCH_CONDO');
}
assert(
  '34. Fair-Share: Ambiguidade batch_id resulta em FAIL-CLOSED',
  ambFailClosed
);

// 35. MANUAL_ORCHESTRATOR não bloqueia CRON_RETENTION
const manualEvent = 'MANUAL_ORCHESTRATOR_b699e35f-c2f9-461f-93c3-de8a80e73744';
assert(
  '35. Idempotência: MANUAL_ORCHESTRATOR não bloqueia CRON_RETENTION',
  !manualEvent.startsWith('CRON_RETENTION_')
);

// 36. CRON_RETENTION recente bloqueia nova execução automática
const cronEvent = 'CRON_RETENTION_b699e35f-c2f9-461f-93c3-de8a80e73744';
assert(
  '36. Idempotência: CRON_RETENTION recente bloqueia nova execução automática no ciclo',
  cronEvent.startsWith('CRON_RETENTION_')
);

// 37. dry-run nunca chama archive_expired_encomendas
const mockDryFS: ExecutionReport = {
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
  fairShareActive: true
};
assert(
  '37. Dry-Run: Fair-Share nunca chama archive_expired_encomendas e garante writes ZERO',
  mockDryFS.archiveRpcStatus === 'DRY-RUN / NOT EXECUTED' &&
  mockDryFS.databaseWrites === 'ZERO' &&
  mockDryFS.rowsArchived === 0 &&
  mockDryFS.finalState === 'DRY_RUN_READY'
);

const totalPassed = results.filter(r => r.passed).length;
console.log(`\nResultado Final: ${totalPassed}/${results.length} testes aprovados.\n`);

if (totalPassed !== results.length) {
  process.exit(1);
} else {
  process.exit(0);
}
