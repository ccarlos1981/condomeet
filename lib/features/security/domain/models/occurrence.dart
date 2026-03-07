enum OccurrenceCategory { maintenance, security, noise, others }
enum OccurrenceStatus { open, inProgress, resolved, closed }

class Occurrence {
  final String id;
  final String resident_id;
  final String condominium_id;
  final String description;
  final OccurrenceCategory category;
  final OccurrenceStatus status;
  final DateTime timestamp;
  final List<String> photoPaths;

  Occurrence({
    required this.id,
    required this.resident_id,
    required this.condominium_id,
    required this.description,
    required this.category,
    this.status = OccurrenceStatus.open,
    required this.timestamp,
    this.photoPaths = const [],
  });

  factory Occurrence.fromMap(Map<String, dynamic> map) {
    return Occurrence(
      id: map['id'],
      resident_id: map['resident_id'],
      condominium_id: map['condominio_id'] ?? map['condominium_id'],
      description: map['description'],
      category: OccurrenceCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => OccurrenceCategory.others,
      ),
      status: OccurrenceStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'open'),
        orElse: () => OccurrenceStatus.open,
      ),
      timestamp: DateTime.parse(map['created_at']),
      photoPaths: List<String>.from(map['photo_paths'] ?? []),
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
      case OccurrenceStatus.inProgress:
        return 'Em Andamento';
      case OccurrenceStatus.resolved:
        return 'Resolvido';
      case OccurrenceStatus.closed:
        return 'Fechado';
    }
  }
}
