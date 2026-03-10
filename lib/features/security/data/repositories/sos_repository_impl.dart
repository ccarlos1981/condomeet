import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import '../../domain/repositories/sos_repository.dart';

class SOSRepositoryImpl implements SOSRepository {
  final PowerSyncService _powerSync;
  final SupabaseClient _supabase;

  SOSRepositoryImpl(this._powerSync, this._supabase);

  // ── Trigger SOS ──────────────────────────────────────────────────────────

  @override
  Future<Result<void>> triggerSOS({
    required String residentId,
    required String condominiumId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final id = const Uuid().v4();
      await _powerSync.db.execute(
        '''
        INSERT INTO sos_alertas (id, resident_id, condominio_id, latitude, longitude, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          id,
          residentId,
          condominiumId,
          latitude,
          longitude,
          'active',
          DateTime.now().toIso8601String(),
          DateTime.now().toIso8601String(),
        ],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao ativar SOS: ${e.toString()}');
    }
  }

  // ── Watch active alerts (Porter / Síndico view) ───────────────────────────

  @override
  Stream<List<SOSAlert>> watchActiveAlerts(String condominiumId) {
    return _powerSync.db.watch(
      '''
      SELECT s.* FROM sos_alertas s
      JOIN perfil p ON s.resident_id = p.id
      WHERE s.condominio_id = ? AND s.status = 'active'
      ORDER BY s.created_at DESC
      ''',
      parameters: [condominiumId],
    ).map((rows) => rows.map((row) => SOSAlert.fromMap(row)).toList());
  }

  // ── Acknowledge alert ────────────────────────────────────────────────────

  @override
  Future<Result<void>> acknowledgeAlert(String alertId, String porterId) async {
    try {
      await _powerSync.db.execute(
        'UPDATE sos_alertas SET status = ?, acknowledged_by = ?, updated_at = ? WHERE id = ?',
        ['resolved', porterId, DateTime.now().toIso8601String(), alertId],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao reconhecer SOS: ${e.toString()}');
    }
  }

  // ── SOS Contatos (via Supabase REST) ─────────────────────────────────────

  @override
  Future<Result<void>> saveSosContatos({
    required String userId,
    required SosContatos contatos,
  }) async {
    try {
      final data = contatos.toMap();
      // Upsert: if a record already exists for this user_id, update it
      await _supabase.from('sos_contatos').upsert(data, onConflict: 'user_id');
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao salvar contatos SOS: ${e.toString()}');
    }
  }

  @override
  Future<SosContatos?> getSosContatos(String userId) async {
    try {
      final response = await _supabase
          .from('sos_contatos')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (response == null) return null;
      return SosContatos.fromMap(response);
    } catch (e) {
      return null;
    }
  }
}
