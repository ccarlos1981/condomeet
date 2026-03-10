enum OccurrenceCategory { maintenance, security, noise, others }
enum OccurrenceStatus { open, pending, inProgress, resolved, closed }

class Occurrence {
  final String id;
  final String resident_id;
  final String condominio_id;
  final String assunto;
  final String description;
  final OccurrenceCategory category;
  final OccurrenceStatus status;
  final DateTime timestamp;
  final List<String> photoPaths;
  final String? photoUrl;
  final String? adminResponse;
  final DateTime? adminResponseAt;

  Occurrence({
    required this.id,
    required this.resident_id,
    required this.condominio_id,
    this.assunto = '',
    required this.description,
    required this.category,
    this.status = OccurrenceStatus.open,
    required this.timestamp,
    this.photoPaths = const [],
    this.photoUrl,
    this.adminResponse,
    this.adminResponseAt,
  });

  factory Occurrence.fromMap(Map<String, dynamic> map) {
    return Occurrence(
      id: map['id'],
      resident_id: map['resident_id'],
      condominio_id: map['condominio_id'] ?? map['condominium_id'],
      assunto: map['assunto'] ?? '',
      description: map['description'] ?? '',
      category: OccurrenceCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => OccurrenceCategory.others,
      ),
      status: OccurrenceStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'open'),
        orElse: () => OccurrenceStatus.open,
      ),
      timestamp: DateTime.parse(map['created_at']),
      photoPaths: List<String>.from(map['photo_paths'] != null
          ? (map['photo_paths'] is List
              ? map['photo_paths']
              : [])
          : []),
      photoUrl: map['photo_url'] as String?,
      adminResponse: map['admin_response'] as String?,
      adminResponseAt: map['admin_response_at'] != null
          ? DateTime.tryParse(map['admin_response_at'])
          : null,
    );
  }

  String get categoryName {
    switch (category) {
      case OccurrenceCategory.maintenance:
        return 'Manutenção';
      case OccurrenceCategory.security:
        return 'Segurança';
      case OccurrenceCategory.noise:
        return 'Barulho';
      case OccurrenceCategory.others:
        return 'Outros';
    }
  }

  String get statusName {
    switch (status) {
      case OccurrenceStatus.open:
        return 'Aberto';
      case OccurrenceStatus.pending:
        return 'Pendente';
      case OccurrenceStatus.inProgress:
        return 'Em Andamento';
      case OccurrenceStatus.resolved:
        return 'Resolvido';
      case OccurrenceStatus.closed:
        return 'Fechado';
    }
  }

  bool get hasAdminResponse => adminResponse != null && adminResponse!.isNotEmpty;
}
