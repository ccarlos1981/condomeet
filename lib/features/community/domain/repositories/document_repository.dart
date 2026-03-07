import 'package:condomeet/features/community/domain/models/document.dart';

abstract class DocumentRepository {
  /// Watches all documents for a condominium.
  Stream<List<CondoDocument>> watchDocuments(String condominiumId);
}
