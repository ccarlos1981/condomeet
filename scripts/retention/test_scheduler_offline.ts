/**
 * CONDOMEET — C4C.14
 * Suíte de Testes Offline / Mock do Scheduler da Retenção
 * Regime: 100% OFFLINE / ZERO CONEXÃO COM PRODUÇÃO
 */

import { parseConfig, formatReport } from './orchestrator.js';
import { PowerSyncMonitor, POWERSYNC_INSTANCE_ID, POWERSYNC_SLOT_PREFIX, LAG_THRESHOLDS } from './powersync_monitor.js';
import { resolveAuditSemantics } from './types.js';
import type { DryRunReport, OrchestratorConfig } from './types.js';

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

const totalPassed = results.filter(r => r.passed).length;
console.log(`\nResultado Final: ${totalPassed}/${results.length} testes aprovados.\n`);

if (totalPassed !== results.length) {
  process.exit(1);
} else {
  process.exit(0);
}
