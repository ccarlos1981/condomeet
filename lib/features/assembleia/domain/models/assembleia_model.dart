/// Modelo da Assembleia — visão do morador (Flutter)
/// Alinhado com schema web (assembleias + assembleia_pautas)
class AssembleiaModel {
  final String id;
  final String condominioId;
  final String nome;
  final String tipo; // AGO, AGE, AGI
  final String modalidade; // online, presencial, hibrida
  final String status; // rascunho, agendada, em_andamento, encerrada, cancelada
  final String tipoTransmissao; // agora, youtube
  final String? youtubeUrl;
  final String? dt1aConvocacao;
  final String? dt2aConvocacao;
  final String? dtInicioVotacao;
  final String? dtFimVotacao;
  final String? dtInicioTransmissao;
  final String? dtFimTransmissao;
  final String? localPresencial;
  final String? editalUrl;
  final String? ataUrl;
  final String? gravacaoUrl;
  final String createdAt;

  const AssembleiaModel({
    required this.id,
    required this.condominioId,
    required this.nome,
    required this.tipo,
    required this.modalidade,
    required this.status,
    this.tipoTransmissao = 'youtube',
    this.youtubeUrl,
    this.dt1aConvocacao,
    this.dt2aConvocacao,
    this.dtInicioVotacao,
    this.dtFimVotacao,
    this.dtInicioTransmissao,
    this.dtFimTransmissao,
    this.localPresencial,
    this.editalUrl,
    this.ataUrl,
    this.gravacaoUrl,
    required this.createdAt,
  });

  factory AssembleiaModel.fromMap(Map<String, dynamic> map) {
    return AssembleiaModel(
      id: map['id'] ?? '',
      condominioId: map['condominio_id'] ?? '',
      nome: map['nome'] ?? '',
      tipo: map['tipo'] ?? 'AGO',
      modalidade: map['modalidade'] ?? 'online',
      status: map['status'] ?? 'rascunho',
      tipoTransmissao: map['tipo_transmissao'] ?? 'youtube',
      youtubeUrl: map['youtube_url'],
      dt1aConvocacao: map['dt_1a_convocacao'],
      dt2aConvocacao: map['dt_2a_convocacao'],
      dtInicioVotacao: map['dt_inicio_votacao'],
      dtFimVotacao: map['dt_fim_votacao'],
      dtInicioTransmissao: map['dt_inicio_transmissao'],
      dtFimTransmissao: map['dt_fim_transmissao'],
      localPresencial: map['local_presencial'],
      editalUrl: map['edital_url'],
      ataUrl: map['ata_url'],
      gravacaoUrl: map['gravacao_url'],
      createdAt: map['created_at'] ?? '',
    );
  }

  bool get isLive => status == 'em_andamento';
  bool get isScheduled => status == 'agendada';
  bool get isFinished => status == 'encerrada' || status == 'cancelada';
  bool get isYoutube => tipoTransmissao == 'youtube';

  String get tipoLabel {
    switch (tipo) {
      case 'AGO':
        return 'Assembleia Geral Ordinária';
      case 'AGE':
        return 'Assembleia Geral Extraordinária';
      case 'AGI':
        return 'Assembleia Geral de Instalação';
      default:
        return tipo;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'rascunho':
        return 'Rascunho';
      case 'agendada':
        return 'Agendada';
      case 'em_andamento':
        return 'Ao Vivo';
      case 'encerrada':
        return 'Encerrada';
      case 'cancelada':
        return 'Cancelada';
      default:
        return status;
    }
  }
}
