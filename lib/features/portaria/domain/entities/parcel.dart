import 'package:equatable/equatable.dart';

class Parcel extends Equatable {
  final String id;
  final String? residentId;
  final String residentName;
  final String unitNumber;
  final String block;
  final DateTime arrivalTime;
  final DateTime? deliveryTime;
  final String? photoUrl;
  final String? pickupProofUrl;
  final String status; // 'pending', 'delivered'
  final String? condominiumId;
  // New fields
  final String? tipo;          // 'caixa','envelope','pacote','notif_judicial'
  final String? trackingCode;
  final String? observacao;
  final String? registeredBy;  // UUID of porter who registered
  final String? pickedUpById;
  final String? pickedUpByName;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancellationReason;

  const Parcel({
    required this.id,
    this.residentId,
    required this.residentName,
    required this.unitNumber,
    required this.block,
    required this.arrivalTime,
    this.deliveryTime,
    this.photoUrl,
    this.pickupProofUrl,
    this.status = 'pending',
    this.condominiumId,
    this.tipo,
    this.trackingCode,
    this.observacao,
    this.registeredBy,
    this.pickedUpById,
    this.pickedUpByName,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
  });

  @override
  List<Object?> get props => [
    id, residentId, residentName, unitNumber, block,
    arrivalTime, deliveryTime, photoUrl, pickupProofUrl,
    status, condominiumId, tipo, trackingCode, observacao,
    registeredBy, pickedUpById, pickedUpByName,
    cancelledAt, cancelledBy, cancellationReason,
  ];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'resident_id': residentId,
      'condominio_id': condominiumId,
      'status': status,
      'arrival_time': arrivalTime.toIso8601String(),
      'delivery_time': deliveryTime?.toIso8601String(),
      'photo_url': photoUrl,
      'pickup_proof_url': pickupProofUrl,
      'tipo': tipo,
      'tracking_code': trackingCode,
      'observacao': observacao,
      'registered_by': registeredBy,
      'picked_up_by_id': pickedUpById,
      'picked_up_by_name': pickedUpByName,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancelled_by': cancelledBy,
      'cancellation_reason': cancellationReason,
    };
  }

  Parcel copyWith({
    String? id,
    String? residentId,
    String? residentName,
    String? unitNumber,
    String? block,
    DateTime? arrivalTime,
    DateTime? deliveryTime,
    String? photoUrl,
    String? pickupProofUrl,
    String? status,
    String? condominiumId,
    String? tipo,
    String? trackingCode,
    String? observacao,
    String? registeredBy,
    String? pickedUpById,
    String? pickedUpByName,
    DateTime? cancelledAt,
    String? cancelledBy,
    String? cancellationReason,
  }) {
    return Parcel(
      id: id ?? this.id,
      residentId: residentId ?? this.residentId,
      residentName: residentName ?? this.residentName,
      unitNumber: unitNumber ?? this.unitNumber,
      block: block ?? this.block,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      photoUrl: photoUrl ?? this.photoUrl,
      pickupProofUrl: pickupProofUrl ?? this.pickupProofUrl,
      status: status ?? this.status,
      condominiumId: condominiumId ?? this.condominiumId,
      tipo: tipo ?? this.tipo,
      trackingCode: trackingCode ?? this.trackingCode,
      observacao: observacao ?? this.observacao,
      registeredBy: registeredBy ?? this.registeredBy,
      pickedUpById: pickedUpById ?? this.pickedUpById,
      pickedUpByName: pickedUpByName ?? this.pickedUpByName,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }
}
