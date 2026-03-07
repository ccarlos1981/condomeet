import 'package:equatable/equatable.dart';

class Apartamento extends Equatable {
  final String id;
  final String condominiumId;
  final String numero;
  final DateTime createdAt;

  const Apartamento({
    required this.id,
    required this.condominiumId,
    required this.numero,
    required this.createdAt,
  });

  factory Apartamento.fromJson(Map<String, dynamic> json) {
    return Apartamento(
      id: json['id'] as String,
      condominiumId: (json['condominio_id'] ?? json['condominium_id']) as String,
      numero: json['numero'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'condominio_id': condominiumId,
      'numero': numero,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, condominiumId, numero, createdAt];
}
