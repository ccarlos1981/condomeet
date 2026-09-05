class Fornecedor {
  final String id;
  final String condominioId;
  final String nome;
  final String tipo;
  final String? telefone;
  final String? documento;
  final String? observacoes;
  final bool ativo;

  const Fornecedor({
    required this.id,
    required this.condominioId,
    required this.nome,
    required this.tipo,
    this.telefone,
    this.documento,
    this.observacoes,
    this.ativo = true,
  });

  factory Fornecedor.fromMap(Map<String, dynamic> map) {
    return Fornecedor(
      id: map['id'] as String,
      condominioId: map['condominio_id'] as String? ?? '',
      nome: map['nome'] as String? ?? '',
      tipo: map['tipo'] as String? ?? 'Pessoa Jurídica',
      telefone: map['telefone'] as String?,
      documento: map['documento'] as String?,
      observacoes: map['observacoes'] as String?,
      ativo: map['ativo'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'condominio_id': condominioId,
      'nome': nome,
      'tipo': tipo,
      'telefone': telefone,
      'documento': documento,
      'observacoes': observacoes,
      'ativo': ativo,
    };
  }
}
