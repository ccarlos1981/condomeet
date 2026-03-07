import 'dart:convert';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:uuid/uuid.dart';
import 'package:condomeet/features/security/domain/models/occurrence.dart';
import 'package:condomeet/features/security/domain/repositories/occurrence_repository.dart';

class OccurrenceRepositoryImpl implements OccurrenceRepository {
  final PowerSyncService _powerSync;

  OccurrenceRepositoryImpl(this._powerSync);

  @override
  Future<Result<void>> reportOccurrence({
    required String residentId,
    required String condominiumId,
    required String description,
    required OccurrenceCategory category,
    List<String> photoPaths = const [],
  }) async {
    try {
      final id = const Uuid().v4();
      final now = DateTime.now().toIso8601String(); // Define 'now'
      final photoPathsJson = jsonEncode(photoPaths); // Define 'photoPathsJson'

      await _powerSync.db.execute(
        '''
        INSERT INTO ocorrencias (id, resident_id, condominium_id, description, category, status, photo_paths, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          id,
          residentId,
          condominiumId,
          description,
          category
              .name, // category.name as per original logic, assuming category is enum
          'pending', // Changed 'open' to 'pending' and moved to parameters
          photoPathsJson,
          now,
          now,
        ],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao registrar ocorrência: ${e.toString()}');
    }
  }

  @override
  Stream<List<Occurrence>> watchResidentOccurrences(String residentId) {
    return _powerSync.db
        .watch(
          'SELECT * FROM ocorrencias WHERE resident_id = ? ORDER BY created_at DESC',
          parameters: [residentId],
        )
        .map((rows) => rows.map((row) => Occurrence.fromMap(row)).toList());
  }

  @override
  Stream<List<Occurrence>> watchAllOccurrences(String condominiumId) {
    return _powerSync.db
        .watch(
          'SELECT * FROM ocorrencias WHERE condominium_id = ? ORDER BY created_at DESC',
          parameters: [condominiumId],
        )
        .map((rows) => rows.map((row) => Occurrence.fromMap(row)).toList());
  }

  @override
  Future<Result<void>> updateOccurrenceStatus(
    String occurrenceId,
    OccurrenceStatus status,
  ) async {
    try {
      await _powerSync.db.execute(
        'UPDATE ocorrencias SET status = ?, updated_at = ? WHERE id = ?',
        [status.name, DateTime.now().toIso8601String(), occurrenceId],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao atualizar status: ${e.toString()}');
    }
  }
}
