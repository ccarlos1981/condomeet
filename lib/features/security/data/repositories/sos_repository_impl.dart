import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:condomeet/core/errors/result.dart';
import '../../domain/repositories/sos_repository.dart';

class SOSRepositoryImpl implements SOSRepository {
  final SupabaseClient _supabase;

  SOSRepositoryImpl(this._supabase);

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
      final now = DateTime.now().toIso8601String();
      // Use Supabase directly so the alert is immediately visible to
      // porters/admins without waiting for PowerSync propagation.
      await _supabase.from('sos_alertas').insert({
        'id': id,
        'resident_id': residentId,
        'condominio_id': condominiumId,
        'latitude': latitude,
        'longitude': longitude,
        'status': 'active',
        'created_at': now,
        'updated_at': now,
      });
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao ativar SOS: ${e.toString()}');
    }
  }

  // ── Watch active alerts (Porter / Síndico view) ───────────────────────────

  @override
  Stream<List<SOSAlert>> watchActiveAlerts(String condominiumId) {
    // Poll every 5s — SOS is time-critical, needs fast updates across devices.
    return Stream.fromIterable([0])
        .asyncExpand((_) async* {
          yield await _fetchActiveAlerts(condominiumId);
          await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
            yield await _fetchActiveAlerts(condominiumId);
          }
        })
        .handleError((e) => print('❌ watchActiveAlerts error: $e'));
  }

  Future<List<SOSAlert>> _fetchActiveAlerts(String condominiumId) async {
    final rows = await _supabase
        .from('sos_alertas')
        .select()
        .eq('condominio_id', condominiumId)
        .eq('status', 'active')
        .order('created_at', ascending: false);
    return (rows as List).map((r) => SOSAlert.fromMap(r as Map<String, dynamic>)).toList();
  }

  // ── Acknowledge alert ────────────────────────────────────────────────────

  @override
  Future<Result<void>> acknowledgeAlert(String alertId, String porterId) async {
    try {
      // Use Supabase directly — porta must be able to acknowledge any condo alert.
      await _supabase.from('sos_alertas').update({
        'status': 'resolved',
        'acknowledged_by': porterId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', alertId);
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
