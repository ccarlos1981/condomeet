enum DocumentCategory { minutes, regulations, forms, others }

class CondoDocument {
  final String id;
  final String title;
  final DocumentCategory category;
  final DateTime uploadDate;
  final String fileUrl; // Mock URL or path
  final String fileExtension;

  CondoDocument({
    required this.id,
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
}
