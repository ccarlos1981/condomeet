enum DocumentCategory { minutes, regulations, forms, others }

class CondoDocument {
  final String id;
  final String condominiumId;
  final String title;
  final DocumentCategory category;
  final DateTime uploadDate;
  final String fileUrl;
  final String fileExtension;

  CondoDocument({
    required this.id,
    required this.condominiumId,
    required this.title,
    required this.category,
    required this.uploadDate,
    required this.fileUrl,
    required this.fileExtension,
  });

  String get categoryName {
    switch (category) {
      case DocumentCategory.minutes:
        return 'Atas de Reunião';
      case DocumentCategory.regulations:
        return 'Regimentos e Normas';
      case DocumentCategory.forms:
        return 'Formulários';
      case DocumentCategory.others:
        return 'Outros';
    }
  }

  factory CondoDocument.fromMap(Map<String, dynamic> map) {
    return CondoDocument(
      id: map['id'],
      condominiumId: map['condominio_id'] ?? map['condominium_id'],
      title: map['title'],
      category: DocumentCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => DocumentCategory.others,
      ),
      uploadDate: DateTime.parse(map['upload_date']),
      fileUrl: map['file_url'],
      fileExtension: map['file_extension'],
    );
  }
}
