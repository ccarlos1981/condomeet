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
    required this.createdAt,
    required this.updatedAt,
  });

  factory Invitation.fromMap(Map<String, dynamic> map) {
    return Invitation(
      id: map['id'] as String,
      residentId: map['resident_id'] as String,
      condominiumId: map['condominio_id'] as String,
      guestName: map['guest_name'] as String,
      validityDate: DateTime.parse(map['validity_date'] as String),
      qrData: map['qr_data'] as String,
      visitorType: map['visitor_type'] as String?,
      visitorPhone: map['visitor_phone'] as String?,
      observation: map['observation'] as String?,
      status: map['status'] as String? ?? 'active',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
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
        createdAt,
        updatedAt,
      ];
}
