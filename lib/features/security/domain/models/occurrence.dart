enum OccurrenceCategory { maintenance, security, noise, others }
enum OccurrenceStatus { pending, inProgress, resolved }

class Occurrence {
  final String id;
  final String residentId;
  final String description;
  final OccurrenceCategory category;
  final OccurrenceStatus status;
  final DateTime timestamp;
  final List<String> photoPaths;

  Occurrence({
    required this.id,
    required this.residentId,
    required this.description,
    required this.category,
    this.status = OccurrenceStatus.pending,
    required this.timestamp,
    this.photoPaths = const [],
  });

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
      case OccurrenceStatus.pending:
        return 'Pendente';
      case OccurrenceStatus.inProgress:
        return 'Em Andamento';
      case OccurrenceStatus.resolved:
        return 'Resolvido';
    }
  }
}
