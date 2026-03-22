import 'package:equatable/equatable.dart';

class Invitation extends Equatable {
  final String id;
  final String residentId;
  final String condominiumId;
  final String guestName;
  final DateTime validityDate;
  final String qrData;
  final String? visitorType;
  final String? visitorPhone;
  final String? observation;
  final String status; // 'active', 'used', 'expired'
  final bool visitanteCompareceu;
  final String? liberadoPor;
  final DateTime? liberadoEm;
  // Denormalized fields for portaria display (joined from perfil)
  final String? residentName;
  final String? blocoTxt;
  final String? aptoTxt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Invitation({
    required this.id,
    required this.residentId,
    required this.condominiumId,
    required this.guestName,
    required this.validityDate,
    required this.qrData,
    this.visitorType,
    this.visitorPhone,
    this.observation,
    this.status = 'active',
    this.visitanteCompareceu = false,
    this.liberadoPor,
    this.liberadoEm,
    this.residentName,
    this.blocoTxt,
    this.aptoTxt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Invitation.fromMap(Map<String, dynamic> map) {
    return Invitation(
      id: map['id'] as String? ?? '',
      residentId: map['resident_id'] as String? ?? '',
      condominiumId: map['condominio_id'] as String? ?? '',
      guestName: map['guest_name'] as String? ?? '',
      validityDate: map['validity_date'] != null
          ? DateTime.tryParse(map['validity_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      qrData: map['qr_data'] as String? ?? '',
      visitorType: map['visitor_type'] as String?,
      visitorPhone: map['visitor_phone'] as String?,
      observation: map['observation'] as String?,
      status: map['status'] as String? ?? 'active',
      visitanteCompareceu: map['visitante_compareceu'] == 1 ||
          map['visitante_compareceu'] == true,
      liberadoPor: map['liberado_por'] as String?,
      liberadoEm: map['liberado_em'] != null
          ? DateTime.tryParse(map['liberado_em'] as String)
          : null,
      residentName: map['resident_name'] as String?,
      blocoTxt: map['bloco_txt'] as String?,
      aptoTxt: map['apto_txt'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Invitation copyWith({
    bool? visitanteCompareceu,
    String? liberadoPor,
    DateTime? liberadoEm,
  }) {
    return Invitation(
      id: id,
      residentId: residentId,
      condominiumId: condominiumId,
      guestName: guestName,
      validityDate: validityDate,
      qrData: qrData,
      visitorType: visitorType,
      visitorPhone: visitorPhone,
      observation: observation,
      status: status,
      visitanteCompareceu: visitanteCompareceu ?? this.visitanteCompareceu,
      liberadoPor: liberadoPor ?? this.liberadoPor,
      liberadoEm: liberadoEm ?? this.liberadoEm,
      residentName: residentName,
      blocoTxt: blocoTxt,
      aptoTxt: aptoTxt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        residentId,
        condominiumId,
        guestName,
        validityDate,
        qrData,
        visitorType,
        visitorPhone,
        observation,
        status,
        visitanteCompareceu,
        liberadoPor,
        liberadoEm,
        residentName,
        blocoTxt,
        aptoTxt,
        createdAt,
        updatedAt,
      ];
}
