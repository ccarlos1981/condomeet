import 'package:equatable/equatable.dart';

class Bloco extends Equatable {
  final String id;
  final String condominioId;
  final String nomeOuNumero;

  const Bloco({
    required this.id,
    required this.condominioId,
    required this.nomeOuNumero,
  });

  factory Bloco.fromMap(Map<String, dynamic> map) {
    return Bloco(
      id: map['id'],
      condominioId: map['condominio_id'] ?? map['condominium_id'],
      nomeOuNumero: map['nome_ou_numero'],
    );
  }

  @override
  List<Object?> get props => [id, condominioId, nomeOuNumero];
}

class Apartamento extends Equatable {
  final String id;
  final String condominioId;
  final String numero;

  const Apartamento({
    required this.id,
    required this.condominioId,
    required this.numero,
  });

  factory Apartamento.fromMap(Map<String, dynamic> map) {
    return Apartamento(
      id: map['id'],
      condominioId: map['condominio_id'] ?? map['condominium_id'],
      numero: map['numero'],
    );
  }

  @override
  List<Object?> get props => [id, condominioId, numero];
}
