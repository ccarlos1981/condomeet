class CondoDocument {
  final String id;
  final String condominioId;
  final String titulo;
  final String? pastaId;
  final String? pastaNome;
  final String? tipoId; // FONTE CANÔNICA
  final String? tipo; // CAMPO LEGADO DE COMPATIBILIDADE
  final bool semValidade; // NOVO CAMPO
  final String? tipoNome;
  final String? tipoIcone;
  final String? arquivoUrl;
  final String? arquivoNome;
  final String? categoria;
  final String? dataValidade;
  final String? dataExpedicao;
  final bool mostrarMoradores;
  final bool avisarMoradores;
  final String? descricao;

  const CondoDocument({
    required this.id,
    required this.condominioId,
    required this.titulo,
    this.pastaId,
    this.pastaNome,
    this.tipoId,
    this.tipo,
    this.semValidade = false,
    this.tipoNome,
    this.tipoIcone,
    this.arquivoUrl,
    this.arquivoNome,
    this.categoria,
    this.dataValidade,
    this.dataExpedicao,
    this.mostrarMoradores = false,
    this.avisarMoradores = false,
    this.descricao,
  });

  factory CondoDocument.fromMap(Map<String, dynamic> map) {
    // Trata doc_pastas como objeto ou array se veio de join
    String? pNome = map['pasta_nome'] as String?;
    if (pNome == null && map['doc_pastas'] != null) {
      if (map['doc_pastas'] is Map) {
        pNome = (map['doc_pastas'] as Map)['nome'] as String?;
      } else if (map['doc_pastas'] is List && (map['doc_pastas'] as List).isNotEmpty) {
        pNome = ((map['doc_pastas'] as List).first as Map)['nome'] as String?;
      }
    }

    // Trata documento_tipos se veio de join
    String? tNome = map['tipo_nome'] as String?;
    String? tIcone = map['tipo_icone'] as String?;
    if (map['documento_tipos'] != null) {
      if (map['documento_tipos'] is Map) {
        tNome ??= (map['documento_tipos'] as Map)['nome'] as String?;
        tIcone ??= (map['documento_tipos'] as Map)['icone'] as String?;
      } else if (map['documento_tipos'] is List && (map['documento_tipos'] as List).isNotEmpty) {
        tNome ??= ((map['documento_tipos'] as List).first as Map)['nome'] as String?;
        tIcone ??= ((map['documento_tipos'] as List).first as Map)['icone'] as String?;
      }
    }

    return CondoDocument(
      id: map['id'] as String,
      condominioId: map['condominio_id'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      pastaId: map['pasta_id'] as String?,
      pastaNome: pNome,
      tipoId: map['tipo_id'] as String?,
      tipo: map['tipo'] as String?,
      semValidade: map['sem_validade'] == true || map['sem_validade'] == 1,
      tipoNome: tNome,
      tipoIcone: tIcone,
      arquivoUrl: map['arquivo_url'] as String?,
      arquivoNome: map['arquivo_nome'] as String?,
      categoria: map['categoria'] as String?,
      dataValidade: map['data_validade'] as String?,
      dataExpedicao: map['data_expedicao'] as String?,
      mostrarMoradores: (map['mostrar_moradores'] == true || map['mostrar_moradores'] == 1),
      avisarMoradores: (map['avisar_moradores'] == true || map['avisar_moradores'] == 1),
      descricao: map['descricao'] as String?,
    );
  }

  String get extensao {
    if (arquivoNome == null) return '';
    final parts = arquivoNome!.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }
}
