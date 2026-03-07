import 'package:equatable/equatable.dart';

class Unidade extends Equatable {
  final String id;
  final String condominiumId;
  final String blocoId;
  final String apartamentoId;
  final bool bloqueada;
  final DateTime createdAt;
  
  // Extra fields for UI convenience when joined
  final String? blocoNome;
  final String? aptoNumero;

  const Unidade({
    required this.id,
    required this.condominiumId,
    required this.blocoId,
    required this.apartamentoId,
    this.bloqueada = false,
    required this.createdAt,
    this.blocoNome,
    this.aptoNumero,
  });

  Unidade copyWith({
    String? id,
    String? condominiumId,
    String? blocoId,
    String? apartamentoId,
    bool? bloqueada,
    DateTime? createdAt,
    String? blocoNome,
    String? aptoNumero,
  }) {
    return Unidade(
      id: id ?? this.id,
      condominiumId: condominiumId ?? this.condominiumId,
      blocoId: blocoId ?? this.blocoId,
      apartamentoId: apartamentoId ?? this.apartamentoId,
      bloqueada: bloqueada ?? this.bloqueada,
      createdAt: createdAt ?? this.createdAt,
      blocoNome: blocoNome ?? this.blocoNome,
      aptoNumero: aptoNumero ?? this.aptoNumero,
    );
  }

  factory Unidade.fromJson(Map<String, dynamic> json) {
    return Unidade(
      id: json['id'] as String,
      condominiumId: (json['condominio_id'] ?? json['condominium_id']) as String,
      blocoId: json['bloco_id'] as String,
      apartamentoId: json['apartamento_id'] as String,
      bloqueada: json['bloqueada'] == true || json['bloqueada'] == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      blocoNome: json['bloco_nome'] as String?,
      aptoNumero: json['apto_numero'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'condominio_id': condominiumId,
      'bloco_id': blocoId,
      'apartamento_id': apartamentoId,
      'bloqueada': bloqueada ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, condominiumId, blocoId, apartamentoId, bloqueada, createdAt, blocoNome, aptoNumero];
}
