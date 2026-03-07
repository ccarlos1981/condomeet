import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import '../../domain/repositories/sos_repository.dart';

class SOSRepositoryImpl implements SOSRepository {
  final PowerSyncService _powerSync;

  SOSRepositoryImpl(this._powerSync);

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
        INSERT INTO sos_alertas (id, resident_id, condominium_id, latitude, longitude, status, created_at, updated_at)
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
          DateTime.now().toIso8601String()
        ],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao ativar SOS: ${e.toString()}');
    }
  }

  @override
  Stream<List<SOSAlert>> watchActiveAlerts(String condominiumId) {
    return _powerSync.db.watch(
      '''
      SELECT s.* FROM sos_alertas s
      JOIN perfil p ON s.resident_id = p.id
      WHERE s.condominium_id = ? AND s.status = 'active'
      ORDER BY s.created_at DESC
      ''',
      parameters: [condominiumId],
    ).map((rows) => rows.map((row) => SOSAlert.fromMap(row)).toList());
  }

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
}
