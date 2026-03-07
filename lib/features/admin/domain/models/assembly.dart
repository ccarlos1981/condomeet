import 'package:equatable/equatable.dart';

enum AssemblyStatus { draft, active, closed }

class Assembly extends Equatable {
  final String id;
  final String condominiumId;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final AssemblyStatus status;

  const Assembly({
    required this.id,
    required this.condominiumId,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  factory Assembly.fromMap(Map<String, dynamic> map) {
    return Assembly(
      id: map['id'],
      condominiumId: map['condominio_id'] ?? map['condominium_id'],
      title: map['titulo'] ?? map['title'],
      description: map['descricao'] ?? map['description'],
      startDate: DateTime.parse(map['data_inicio'] ?? map['start_date']),
      endDate: DateTime.parse(map['data_fim'] ?? map['end_date']),
      status: AssemblyStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AssemblyStatus.draft,
      ),
    );
  }

  @override
  List<Object?> get props => [id, condominiumId, title, status];
}

class AssemblyOption extends Equatable {
  final String id;
  final String assemblyId;
  final String title;

  const AssemblyOption({
    required this.id,
    required this.assemblyId,
    required this.title,
  });

  factory AssemblyOption.fromMap(Map<String, dynamic> map) {
    return AssemblyOption(
      id: map['id'],
      assemblyId: map['assembleia_id'] ?? map['assembly_id'],
      title: map['titulo'] ?? map['title'],
    );
  }

  @override
  List<Object?> get props => [id, assemblyId, title];
}

class AssemblyVote extends Equatable {
  final String id;
  final String assemblyId;
  final String optionId;
  final String residentId;
  final DateTime createdAt;

  const AssemblyVote({
    required this.id,
    required this.assemblyId,
    required this.optionId,
    required this.residentId,
    required this.createdAt,
  });

  factory AssemblyVote.fromMap(Map<String, dynamic> map) {
    return AssemblyVote(
      id: map['id'],
      assemblyId: map['assembleia_id'] ?? map['assembly_id'],
      optionId: map['opcao_id'] ?? map['option_id'],
      residentId: map['perfil_id'] ?? map['resident_id'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  @override
  List<Object?> get props => [id, assemblyId, optionId, residentId];
}
