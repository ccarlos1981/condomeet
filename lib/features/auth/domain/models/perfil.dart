import 'package:equatable/equatable.dart';

class Unidade extends Equatable {
  final String id;
  final String condominioId;
  final String blocoId;
  final String apartamentoId;
  final bool bloqueada;
  
  // Optional for UI display
  final String? blocoNome;
  final String? apartamentoNumero;

  const Unidade({
    required this.id,
    required this.condominioId,
    required this.blocoId,
    required this.apartamentoId,
    this.bloqueada = false,
    this.blocoNome,
    this.apartamentoNumero,
  });

  factory Unidade.fromMap(Map<String, dynamic> map) {
    return Unidade(
      id: map['id'],
      condominioId: map['condominio_id'] ?? map['condominium_id'],
      blocoId: map['bloco_id'],
      apartamentoId: map['apartamento_id'],
      bloqueada: map['bloqueada'] == 1 || map['bloqueada'] == true,
      blocoNome: map['nome_ou_numero'], // If joined
      apartamentoNumero: map['numero'], // If joined
    );
  }

  @override
  List<Object?> get props => [id, condominioId, blocoId, apartamentoId, bloqueada];
}

class Perfil extends Equatable {
  final String id;
  final String? condominioId;
  final String nomeCompleto;
  final String? whatsapp;
  final bool whatsappMsgConsent;
  final bool bloqueado;
  final String statusAprovacao; // 'pendente', 'aprovado', 'rejeitado'
  final String? tipoMorador;
  final String papelSistema; // 'ADMIN', 'Morador', 'Síndico', etc.
  final String? blocoTxt;
  final String? apto_txt;
  final String? fcmToken;
  final String? botconversaId;
  final DateTime? createdAt;

  const Perfil({
    required this.id,
    this.condominioId,
    required this.nomeCompleto,
    this.whatsapp,
    this.whatsappMsgConsent = true,
    this.bloqueado = false,
    this.statusAprovacao = 'pendente',
    this.tipoMorador,
    this.papelSistema = 'Morador',
    this.blocoTxt,
    this.apto_txt,
    this.fcmToken,
    this.botconversaId,
    this.createdAt,
  });

  factory Perfil.fromMap(Map<String, dynamic> map) {
    return Perfil(
      id: map['id'],
      condominioId: map['condominio_id'],
      nomeCompleto: map['nome_completo'],
      whatsapp: map['whatsapp'],
      whatsappMsgConsent: map['whatsapp_msg_consent'] == 1 || map['whatsapp_msg_consent'] == true,
      bloqueado: map['bloqueado'] == 1 || map['bloqueado'] == true,
      statusAprovacao: map['status_aprovacao'] ?? 'pendente',
      tipoMorador: map['tipo_morador'],
      papelSistema: map['papel_sistema'] ?? 'Morador',
      blocoTxt: map['bloco_txt'],
      apto_txt: map['apto_txt'],
      fcmToken: map['fcm_token'],
      botconversaId: map['botconversa_id'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  @override
  List<Object?> get props => [
    id, condominioId, nomeCompleto, whatsapp, whatsappMsgConsent, 
    bloqueado, statusAprovacao, tipoMorador, papelSistema, 
    blocoTxt, apto_txt, fcmToken, botconversaId, createdAt
  ];
}
