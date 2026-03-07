import 'package:condomeet/core/services/powersync_service.dart';
import 'package:condomeet/features/community/domain/models/document.dart';
import 'package:condomeet/features/community/domain/repositories/document_repository.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  final PowerSyncService _powerSyncService;

  DocumentRepositoryImpl(this._powerSyncService);

  @override
  Stream<List<CondoDocument>> watchDocuments(String condominiumId) {
    return _powerSyncService.db.watch(
      'SELECT * FROM documentos WHERE condominio_id = ? ORDER BY upload_date DESC',
      parameters: [condominiumId],
    ).map((rows) => rows.map((row) => CondoDocument.fromMap(row)).toList());
  }
}
