import 'package:condomeet/core/errors/result.dart';
import '../models/occurrence.dart';

abstract class OccurrenceRepository {
  /// Submits a new occurrence report.
  Future<Result<void>> reportOccurrence({
    required String residentId,
    required String description,
    required OccurrenceCategory category,
    List<String> photoPaths = const [],
  });

  /// Fetches occurrences reported by a specific resident.
  Future<Result<List<Occurrence>>> getResidentOccurrences(String residentId);
}
