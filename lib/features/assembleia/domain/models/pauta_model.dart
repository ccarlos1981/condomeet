/// Modelo de Pauta da Assembleia
/// Alinhado com tabela assembleia_pautas
class PautaModel {
  final String id;
  final String assembleiaId;
  final int ordem;
  final String titulo;
  final String? descricao;
  final String tipo; // votacao, informativo
  final String quorumTipo; // simples, dois_tercos, unanimidade
  final List<String> opcoesVoto;
  final String modoResposta; // unica, multipla
  final int maxEscolhas;
  final bool resultadoVisivel;
  final String? status; // aberta, fechada, encerrada

  const PautaModel({
    required this.id,
    required this.assembleiaId,
    required this.ordem,
    required this.titulo,
    this.descricao,
    this.tipo = 'votacao',
    this.quorumTipo = 'simples',
    this.opcoesVoto = const [],
    this.modoResposta = 'unica',
    this.maxEscolhas = 1,
    this.resultadoVisivel = false,
    this.status,
  });

  factory PautaModel.fromMap(Map<String, dynamic> map) {
    // opcoesVoto can be a JSON array string or a List
    List<String> opcoes = [];
    final raw = map['opcoes_voto'];
    if (raw is List) {
      opcoes = raw.map((e) => e.toString()).toList();
    } else if (raw is String) {
      // Try to parse JSON array
      try {
        final decoded = raw.replaceAll(RegExp(r'[\[\]"]'), '').split(',');
        opcoes = decoded.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } catch (_) {
        opcoes = [];
      }
    }

    return PautaModel(
      id: map['id'] ?? '',
      assembleiaId: map['assembleia_id'] ?? '',
      ordem: (map['ordem'] ?? 0) is int ? map['ordem'] ?? 0 : int.tryParse(map['ordem'].toString()) ?? 0,
      titulo: map['titulo'] ?? '',
      descricao: map['descricao'],
      tipo: map['tipo'] ?? 'votacao',
      quorumTipo: map['quorum_tipo'] ?? 'simples',
      opcoesVoto: opcoes,
      modoResposta: map['modo_resposta'] ?? 'unica',
      maxEscolhas: (map['max_escolhas'] ?? 1) is int ? map['max_escolhas'] ?? 1 : int.tryParse(map['max_escolhas'].toString()) ?? 1,
      resultadoVisivel: map['resultado_visivel'] == true || map['resultado_visivel'] == 1,
      status: map['status'],
    );
  }

  bool get isVotacao => tipo == 'votacao';
  bool get isAberta => status == 'aberta';
  bool get isEncerrada => status == 'encerrada';

  String get quorumLabel {
    switch (quorumTipo) {
      case 'simples':
        return 'Maioria Simples';
      case 'dois_tercos':
        return '2/3 dos Votos';
      case 'unanimidade':
        return 'Unanimidade';
      default:
        return quorumTipo;
    }
  }
}
