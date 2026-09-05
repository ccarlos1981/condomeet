class DocumentoTipo {
  final String id;
  final String? condominioId;
  final String nome;
  final String? descricao;
  final String categoriaPadrao;
  final String icone;
  final bool isSystem;
  final bool ativo;
  final int ordem;
  final bool recorrente;
  final bool normalmenteTemValidade;
  final bool permiteLembrete;
  final bool permiteExibirMoradores;
  final bool permiteNotificacao;

  const DocumentoTipo({
    required this.id,
    this.condominioId,
    required this.nome,
    this.descricao,
    required this.categoriaPadrao,
    required this.icone,
    required this.isSystem,
    this.ativo = true,
    this.ordem = 100,
    this.recorrente = false,
    this.normalmenteTemValidade = false,
    this.permiteLembrete = true,
    this.permiteExibirMoradores = true,
    this.permiteNotificacao = true,
  });

  factory DocumentoTipo.fromMap(Map<String, dynamic> map) {
    return DocumentoTipo(
      id: map['id'] as String,
      condominioId: map['condominio_id'] as String?,
      nome: map['nome'] as String? ?? '',
      descricao: map['descricao'] as String?,
      categoriaPadrao: map['categoria_padrao'] as String? ?? 'Outros',
      icone: map['icone'] as String? ?? 'file-text',
      isSystem: map['is_system'] == true || map['is_system'] == 1,
      ativo: map['ativo'] == true || map['ativo'] == 1,
      ordem: map['ordem'] as int? ?? 100,
      recorrente: map['recorrente'] == true || map['recorrente'] == 1,
      normalmenteTemValidade: map['normalmente_tem_validade'] == true || map['normalmente_tem_validade'] == 1,
      permiteLembrete: map['permite_lembrete'] != false,
      permiteExibirMoradores: map['permite_exibir_moradores'] != false,
      permiteNotificacao: map['permite_notificacao'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'condominio_id': condominioId,
      'nome': nome,
      'descricao': descricao,
      'categoria_padrao': categoriaPadrao,
      'icone': icone,
      'is_system': isSystem,
      'ativo': ativo,
      'ordem': ordem,
      'recorrente': recorrente,
      'normalmente_tem_validade': normalmenteTemValidade,
      'permite_lembrete': permiteLembrete,
      'permite_exibir_moradores': permiteExibirMoradores,
      'permite_notificacao': permiteNotificacao,
    };
  }
}

class DocumentoTipoPrioridade {
  final String id;
  final String condominioId;
  final String tipoId;
  final bool isPrioritario;
  final int ordem;

  const DocumentoTipoPrioridade({
    required this.id,
    required this.condominioId,
    required this.tipoId,
    this.isPrioritario = true,
    this.ordem = 0,
  });

  factory DocumentoTipoPrioridade.fromMap(Map<String, dynamic> map) {
    return DocumentoTipoPrioridade(
      id: map['id'] as String,
      condominioId: map['condominio_id'] as String? ?? '',
      tipoId: map['tipo_id'] as String? ?? '',
      isPrioritario: map['is_prioritario'] == true || map['is_prioritario'] == 1,
      ordem: map['ordem'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'condominio_id': condominioId,
      'tipo_id': tipoId,
      'is_prioritario': isPrioritario,
      'ordem': ordem,
    };
  }
}
