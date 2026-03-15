class CondoDocument {
  final String id;
  final String condominioId;
  final String titulo;
  final String? pastaId;
  final String? pastaNome;
  final String? arquivoUrl;
  final String? arquivoNome;
  final String? categoria;
  final String? dataValidade;
  final String? dataExpedicao;
  final bool mostrarMoradores;
  final String? descricao;

  const CondoDocument({
    required this.id,
    required this.condominioId,
    required this.titulo,
    this.pastaId,
    this.pastaNome,
    this.arquivoUrl,
    this.arquivoNome,
    this.categoria,
    this.dataValidade,
    this.dataExpedicao,
    this.mostrarMoradores = false,
    this.descricao,
  });

  factory CondoDocument.fromMap(Map<String, dynamic> map) {
    return CondoDocument(
      id: map['id'] as String,
      condominioId: map['condominio_id'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      pastaId: map['pasta_id'] as String?,
      pastaNome: map['pasta_nome'] as String?,
      arquivoUrl: map['arquivo_url'] as String?,
      arquivoNome: map['arquivo_nome'] as String?,
      categoria: map['categoria'] as String?,
      dataValidade: map['data_validade'] as String?,
      dataExpedicao: map['data_expedicao'] as String?,
      mostrarMoradores: (map['mostrar_moradores'] == true || map['mostrar_moradores'] == 1),
      descricao: map['descricao'] as String?,
    );
  }

  String get extensao {
    if (arquivoNome == null) return '';
    final parts = arquivoNome!.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }
}
