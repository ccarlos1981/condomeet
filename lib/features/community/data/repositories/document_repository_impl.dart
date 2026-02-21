import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/community/domain/models/document.dart';
import 'package:condomeet/features/community/domain/repositories/document_repository.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  final List<CondoDocument> _mockDocuments = [
    CondoDocument(
      id: '1',
      title: 'Regimento Interno 2024',
      category: DocumentCategory.regulations,
      uploadDate: DateTime(2024, 1, 15),
      fileUrl: 'regimento_2024.pdf',
      fileExtension: 'pdf',
    ),
    CondoDocument(
      id: '2',
      title: 'Ata de Assembleia Extraordinária - Jan/25',
      category: DocumentCategory.minutes,
      uploadDate: DateTime(2025, 1, 10),
      fileUrl: 'ata_jan_25.pdf',
      fileExtension: 'pdf',
    ),
    CondoDocument(
      id: '3',
      title: 'Formulário de Mudança',
      category: DocumentCategory.forms,
      uploadDate: DateTime(2023, 11, 20),
      fileUrl: 'form_mudanca.docx',
      fileExtension: 'docx',
    ),
    CondoDocument(
      id: '4',
      title: 'Convenção do Condomínio',
      category: DocumentCategory.regulations,
      uploadDate: DateTime(2020, 5, 10),
      fileUrl: 'convencao.pdf',
      fileExtension: 'pdf',
    ),
  ];

  @override
  Future<Result<List<CondoDocument>>> getDocuments() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return Success(_mockDocuments);
  }
}

final documentRepository = DocumentRepositoryImpl();
