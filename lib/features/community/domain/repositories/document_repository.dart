import 'package:condomeet/core/errors/result.dart';
import '../models/document.dart';

abstract class DocumentRepository {
  /// Fetches the list of official documents.
  Future<Result<List<CondoDocument>>> getDocuments();
}
