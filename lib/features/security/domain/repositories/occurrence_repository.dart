import 'package:condomeet/core/errors/result.dart';
import '../models/occurrence.dart';

abstract class OccurrenceRepository {
  /// Submits a new occurrence report.
  Future<Result<void>> reportOccurrence({
    required String residentId,
    required String condominiumId,
    required String assunto,
    required String description,
    required OccurrenceCategory category,
    String? photoUrl,
  });

  /// Listens to occurrences reported by a specific resident.
  Stream<List<Occurrence>> watchResidentOccurrences(String residentId);

  /// Listens to all occurrences in a condominium (Staff view).
  Stream<List<Occurrence>> watchAllOccurrences(String condominiumId);

  /// Updates the status of an occurrence.
  Future<Result<void>> updateOccurrenceStatus(String occurrenceId, OccurrenceStatus status);

  /// Admin/Síndico responds to an occurrence.
  Future<Result<void>> respondOccurrence({
    required String occurrenceId,
    required String response,
  });
}
