import 'package:equatable/equatable.dart';

class Condominio extends Equatable {
  final String id;
  final String nome;
  final String? apelido;
  final String? cnpj;
  final String? cep;
  final String? logradouro;
  final String? bairro;
  final String? numero;
  final String? complemento;
  final String? cidade;
  final String? estado;
  final DateTime? createdAt;

  const Condominio({
    required this.id,
    required this.nome,
    this.apelido,
    this.cnpj,
    this.cep,
    this.logradouro,
    this.bairro,
    this.numero,
    this.complemento,
    this.cidade,
    this.estado,
    this.createdAt,
  });

  factory Condominio.fromMap(Map<String, dynamic> map) {
    return Condominio(
      id: map['id'],
      nome: map['nome'],
      apelido: map['apelido'],
      cnpj: map['cnpj'],
      cep: map['cep'],
      logradouro: map['logradouro'],
      bairro: map['bairro'],
      numero: map['numero'],
      complemento: map['complemento'],
      cidade: map['cidade'],
      estado: map['estado'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'apelido': apelido,
      'cnpj': cnpj,
      'cep': cep,
      'logradouro': logradouro,
      'bairro': bairro,
      'numero': numero,
      'complemento': complemento,
      'cidade': cidade,
      'estado': estado,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, nome, apelido, cnpj, cep, logradouro, bairro, numero, complemento, cidade, estado, createdAt];
}
