/**
 * CONDOMEET — ONDA C4B
 * Tipagens Oficiais do Orquestrador de Retenção de Encomendas
 * Modo: DRY-RUN / READ-ONLY
 */

export type PowerSyncState = 'SAFE' | 'WAIT' | 'CONSERVATIVE' | 'STOP';

export type OrchestratorFinalState = 'DRY_RUN_READY' | 'SUCCESS' | 'PARTIAL' | 'STOP' | 'FAILED';

export interface ResolvedSlotInfo {
  slot_name: string;
  plugin: string;
  slot_type: string;
  active: boolean;
  confirmed_flush_lsn: string | null;
  restart_lsn: string | null;
  current_wal_lsn: string;
  lag_bytes: number;
  lag_mb: number;
}

export interface RawSlotData {
  slot_name: string;
  plugin: string;
  slot_type: string;
  active: boolean;
  confirmed_flush_lsn: string | null;
  restart_lsn: string | null;
  lag_bytes?: number | string | null;
}

export interface PowerSyncSlotInfo {
  instance_id: string;
  slot_name: string;
  plugin: string;
  slot_type: string;
  active: boolean;
  confirmed_flush_lsn: string | null;
  restart_lsn: string | null;
  current_wal_lsn: string;
  lag_bytes: number;
  lag_mb: number;
  state: PowerSyncState;
  reason?: string;
  resolved_slot: ResolvedSlotInfo | null;
  total_candidate_slots?: number;
  active_candidate_slots?: number;
}

export type ExecutionSource = 'MANUAL_ORCHESTRATOR' | 'CRON_RETENTION';

export interface AuditSemantics {
  executionSource: ExecutionSource;
  executedBy: string;
  archivedBy: string;
}

export function resolveAuditSemantics(source: ExecutionSource | string | undefined, condominioId: string): AuditSemantics {
  const normSource: ExecutionSource = source === 'CRON_RETENTION' ? 'CRON_RETENTION' : 'MANUAL_ORCHESTRATOR';
  return {
    executionSource: normSource,
    executedBy: `${normSource}_${condominioId}`,
    archivedBy: `${normSource}_${condominioId}`
  };
}

export interface OrchestratorConfig {
  condominioId: string;
  batchSize: number;
  maxBatches: number;
  timeoutMs: number;
  cooldownMs: number;
  isDryRun: boolean;
  killSwitch: boolean;
  executionSource?: ExecutionSource;
}

export interface ExecutionReport {
  postgresStatus: 'CONNECTED' | 'FAILED';
  tlsStatus: 'VALIDATED' | 'FAILED';
  database: string;
  user: string;
  version: string;
  powerSyncState: PowerSyncState;
  powerSyncInstanceId: string;
  slotFound: 'FOUND' | 'NOT FOUND';
  resolvedSlotName: string | null;
  plugin: string | null;
  slotType: string | null;
  active: boolean | null;
  currentWalLsn: string | null;
  confirmedFlushLsn: string | null;
  restartLsn: string | null;
  lagFormatted: string | null;
  killSwitchStatus: 'ON' | 'OFF';
  condominioNome: string | null;
  condominioUuid: string;
  elegiveisAtuais: number | null;
  batchSize: number;
  maxBatches: number;
  isDryRun?: boolean;
  archiveRpcStatus: string;
  leaseStatus: string;
  databaseWrites: string;
  rowsArchived: number;
  rowsDelivered10d?: number;
  rowsPending3m?: number;
  batchesProcessed?: number;
  durationMs?: number;
  batchId?: string | null;
  rpcErrorMessage?: string | null;
  postLagBytes?: number;
  finalState: OrchestratorFinalState;
  stopReason?: string;
  executionSource: ExecutionSource;
  executedBy?: string;
  archivedBy?: string;
  // Retrocompatibilidade para relatórios existentes
  simulatedExecutedBy?: string;
  simulatedArchivedBy?: string;
}

export type DryRunReport = ExecutionReport;

