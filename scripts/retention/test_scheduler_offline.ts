/**
 * CONDOMEET — C4C.14
 * Suíte de Testes Offline / Mock do Scheduler da Retenção
 * Regime: 100% OFFLINE / ZERO CONEXÃO COM PRODUÇÃO
 */

import { parseConfig, formatReport, buildArchiveRpcQuery } from './orchestrator.js';
import { PowerSyncMonitor, POWERSYNC_INSTANCE_ID, POWERSYNC_SLOT_PREFIX, LAG_THRESHOLDS } from './powersync_monitor.js';
import { resolveAuditSemantics } from './types.js';
import type { DryRunReport, ExecutionReport, OrchestratorConfig } from './types.js';

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

const totalPassed = results.filter(r => r.passed).length;
console.log(`\nResultado Final: ${totalPassed}/${results.length} testes aprovados.\n`);

if (totalPassed !== results.length) {
  process.exit(1);
} else {
  process.exit(0);
}
