/**
 * CONDOMEET — ONDA C4B
 * Monitor Dedicado do Slot de Replicação do PowerSync
 * Catálogo: pg_replication_slots
 * Slot Oficial: powersync_69a342260f29674a8633a165_8_f71f
 */

import type { Client } from 'pg';
import type { PowerSyncSlotInfo, PowerSyncState, RawSlotData, ResolvedSlotInfo } from './types.js';

export const POWERSYNC_INSTANCE_ID = '69a342260f29674a8633a165';
export const POWERSYNC_SLOT_PREFIX = `powersync_${POWERSYNC_INSTANCE_ID}_`;

export const LAG_THRESHOLDS = {
  SAFE_MAX_BYTES: 5 * 1024 * 1024,        // 5 MB
  WAIT_MAX_BYTES: 10 * 1024 * 1024,       // 10 MB
  CONSERVATIVE_MAX_BYTES: 50 * 1024 * 1024 // 50 MB
};

export class PowerSyncMonitor {
  /**
   * Resolução dinâmica e avaliação fail-closed de slots de replicação.
   * Não escolhe arbitrariamente nem faz fallback para slots inativos.
   */
  public static resolveAndEvaluateSlots(params: {
    slots: RawSlotData[];
    currentWalLsn: string;
    instanceId?: string;
  }): PowerSyncSlotInfo {
    const instanceId = params.instanceId || POWERSYNC_INSTANCE_ID;
    const prefix = `powersync_${instanceId}_`;

    // 1. Filtrar slots correspondentes à instância oficial
    const matchingSlots = params.slots.filter(
      s => s.slot_name && s.slot_name.startsWith(prefix)
    );

    if (matchingSlots.length === 0) {
      return {
        instance_id: instanceId,
        slot_name: 'NONE',
        plugin: 'unknown',
        slot_type: 'unknown',
        active: false,
        confirmed_flush_lsn: null,
        restart_lsn: null,
        current_wal_lsn: params.currentWalLsn,
        lag_bytes: 0,
        lag_mb: 0,
        state: 'STOP',
        reason: `STOP_NO_ACTIVE_POWERSYNC_SLOT: Nenhum slot de replicação encontrado para a instância '${instanceId}'.`,
        resolved_slot: null,
        total_candidate_slots: 0,
        active_candidate_slots: 0
      };
    }

    // 2. Validar compatibilidade de slots ativos da instância
    const incompatibleActive = matchingSlots.filter(
      s => s.active === true && (s.plugin !== 'pgoutput' || s.slot_type !== 'logical')
    );
    if (incompatibleActive.length > 0) {
      const invalid = incompatibleActive[0];
      return {
        instance_id: instanceId,
        slot_name: invalid.slot_name,
        plugin: invalid.plugin,
        slot_type: invalid.slot_type,
        active: invalid.active,
        confirmed_flush_lsn: invalid.confirmed_flush_lsn,
        restart_lsn: invalid.restart_lsn,
        current_wal_lsn: params.currentWalLsn,
        lag_bytes: 0,
        lag_mb: 0,
        state: 'STOP',
        reason: `STOP_INVALID_POWERSYNC_SLOT: Slot '${invalid.slot_name}' possui configuração incompatível (plugin='${invalid.plugin}', type='${invalid.slot_type}'). Esperado 'pgoutput' e 'logical'.`,
        resolved_slot: null,
        total_candidate_slots: matchingSlots.length,
        active_candidate_slots: incompatibleActive.length
      };
    }

    // 3. Filtrar slots ativos compatíveis
    const activeCompatible = matchingSlots.filter(
      s => s.active === true && s.plugin === 'pgoutput' && s.slot_type === 'logical'
    );

    // Caso B: nenhum slot ativo compatível
    if (activeCompatible.length === 0) {
      const firstSlot = matchingSlots[0];
      return {
        instance_id: instanceId,
        slot_name: firstSlot.slot_name,
        plugin: firstSlot.plugin,
        slot_type: firstSlot.slot_type,
        active: false,
        confirmed_flush_lsn: firstSlot.confirmed_flush_lsn,
        restart_lsn: firstSlot.restart_lsn,
        current_wal_lsn: params.currentWalLsn,
        lag_bytes: 0,
        lag_mb: 0,
        state: 'STOP',
        reason: `STOP_NO_ACTIVE_POWERSYNC_SLOT: Todos os slots encontrados para a instância '${instanceId}' encontram-se inativos (${matchingSlots.map(s => s.slot_name).join(', ')}).`,
        resolved_slot: null,
        total_candidate_slots: matchingSlots.length,
        active_candidate_slots: 0
      };
    }

    // Caso C: mais de 1 slot ativo compatível (Ambiguidade estritamente proibida)
    if (activeCompatible.length > 1) {
      return {
        instance_id: instanceId,
        slot_name: 'AMBIGUOUS',
        plugin: 'pgoutput',
        slot_type: 'logical',
        active: true,
        confirmed_flush_lsn: null,
        restart_lsn: null,
        current_wal_lsn: params.currentWalLsn,
        lag_bytes: 0,
        lag_mb: 0,
        state: 'STOP',
        reason: `STOP_AMBIGUOUS_POWERSYNC_SLOT: Foram encontrados ${activeCompatible.length} slots ativos compatíveis para a instância '${instanceId}' (${activeCompatible.map(s => s.slot_name).join(', ')}). Ambiguidade não permitida.`,
        resolved_slot: null,
        total_candidate_slots: matchingSlots.length,
        active_candidate_slots: activeCompatible.length
      };
    }

    // Caso A: exatamente 1 slot ativo compatível
    const chosen = activeCompatible[0];
    const lagBytes = typeof chosen.lag_bytes === 'string'
      ? parseInt(chosen.lag_bytes, 10)
      : (Number(chosen.lag_bytes) || 0);
    const lagMb = Number((lagBytes / (1024 * 1024)).toFixed(2));

    const resolved: ResolvedSlotInfo = {
      slot_name: chosen.slot_name,
      plugin: chosen.plugin,
      slot_type: chosen.slot_type,
      active: true,
      confirmed_flush_lsn: chosen.confirmed_flush_lsn,
      restart_lsn: chosen.restart_lsn,
      current_wal_lsn: params.currentWalLsn,
      lag_bytes: lagBytes,
      lag_mb: lagMb
    };

    let state: PowerSyncState = 'SAFE';
    let reason: string | undefined;

    if (lagBytes < LAG_THRESHOLDS.SAFE_MAX_BYTES) {
      state = 'SAFE';
    } else if (lagBytes >= LAG_THRESHOLDS.SAFE_MAX_BYTES && lagBytes < LAG_THRESHOLDS.WAIT_MAX_BYTES) {
      state = 'WAIT';
      reason = `PowerSync WAL lag moderado (${lagMb} MB). Aguardando drenagem.`;
    } else if (lagBytes >= LAG_THRESHOLDS.WAIT_MAX_BYTES && lagBytes < LAG_THRESHOLDS.CONSERVATIVE_MAX_BYTES) {
      state = 'CONSERVATIVE';
      reason = `PowerSync WAL lag elevado (${lagMb} MB). Modo conservador ativado.`;
    } else {
      state = 'STOP';
      reason = `PowerSync WAL lag crítico (${lagMb} MB >= 50 MB). Parada imediata de proteção.`;
    }

    return {
      instance_id: instanceId,
      slot_name: chosen.slot_name,
      plugin: chosen.plugin,
      slot_type: chosen.slot_type,
      active: true,
      confirmed_flush_lsn: chosen.confirmed_flush_lsn,
      restart_lsn: chosen.restart_lsn,
      current_wal_lsn: params.currentWalLsn,
      lag_bytes: lagBytes,
      lag_mb: lagMb,
      state,
      reason,
      resolved_slot: resolved,
      total_candidate_slots: matchingSlots.length,
      active_candidate_slots: 1
    };
  }

  /**
   * Consulta o catálogo nativo pg_replication_slots com SSL estrito.
   * Resolve dinamicamente o slot pertencente à instância oficial.
   */
  public async checkSlot(client: Client): Promise<PowerSyncSlotInfo> {
    const walRes = await client.query('SELECT pg_current_wal_lsn() AS current_wal_lsn;');
    const currentWalLsn = walRes.rows[0]?.current_wal_lsn || '0/0';

    const query = `
      SELECT 
        slot_name,
        plugin,
        slot_type,
        active,
        confirmed_flush_lsn,
        restart_lsn,
        pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) AS lag_bytes
      FROM pg_replication_slots
      WHERE slot_name LIKE $1
      ORDER BY slot_name;
    `;

    const res = await client.query(query, [`${POWERSYNC_SLOT_PREFIX}%`]);

    return PowerSyncMonitor.resolveAndEvaluateSlots({
      slots: res.rows,
      currentWalLsn: currentWalLsn,
      instanceId: POWERSYNC_INSTANCE_ID
    });
  }
}
