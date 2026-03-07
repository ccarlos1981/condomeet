import 'package:equatable/equatable.dart';

class Bloco extends Equatable {
  final String id;
  final String condominiumId;
  final String nomeOuNumero;
  final DateTime createdAt;

  const Bloco({
    required this.id,
    required this.condominiumId,
    required this.nomeOuNumero,
    required this.createdAt,
  });

  factory Bloco.fromJson(Map<String, dynamic> json) {
    return Bloco(
      id: json['id'] as String,
      condominiumId: (json['condominio_id'] ?? json['condominium_id']) as String,
      nomeOuNumero: json['nome_ou_numero'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'condominio_id': condominiumId,
      'nome_ou_numero': nomeOuNumero,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, condominiumId, nomeOuNumero, createdAt];
}
