import 'package:equatable/equatable.dart';

class Parcel extends Equatable {
  final String id;
  final String residentId;
  final String residentName;
  final String unitNumber;
  final String block;
  final DateTime arrivalTime;
  final DateTime? deliveryTime;
  final String? photoUrl;
  final String? pickupProofUrl;
  final String status; // 'pending', 'delivered'
  final String? condominiumId;

  const Parcel({
    required this.id,
    required this.residentId,
    required this.residentName,
    required this.unitNumber,
    required this.block,
    required this.arrivalTime,
    this.deliveryTime,
    this.photoUrl,
    this.pickupProofUrl,
    this.status = 'pending',
    this.condominiumId,
  });

  @override
  List<Object?> get props => [
    id,
    residentId,
    residentName,
    unitNumber,
    block,
    arrivalTime,
    deliveryTime,
    photoUrl,
    pickupProofUrl,
    status,
    condominiumId,
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
    );
  }
}
