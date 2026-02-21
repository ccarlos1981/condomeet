import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/security/domain/models/occurrence.dart';
import 'package:condomeet/features/security/domain/repositories/occurrence_repository.dart';

class OccurrenceRepositoryImpl implements OccurrenceRepository {
  final List<Occurrence> _mockOccurrences = [];

  @override
  Future<Result<void>> reportOccurrence({
    required String residentId,
    required String description,
    required OccurrenceCategory category,
    List<String> photoPaths = const [],
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final newOccurrence = Occurrence(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      residentId: residentId,
      description: description,
      category: category,
      timestamp: DateTime.now(),
      photoPaths: photoPaths,
    );

    _mockOccurrences.add(newOccurrence);
    return const Success(null);
  }

  @override
  Future<Result<List<Occurrence>>> getResidentOccurrences(String residentId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final results = _mockOccurrences.where((o) => o.residentId == residentId).toList();
    return Success(results);
  }
}
