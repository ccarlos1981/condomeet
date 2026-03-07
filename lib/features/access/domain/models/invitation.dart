import 'package:equatable/equatable.dart';

class Invitation extends Equatable {
  final String id;
  final String residentId;
  final String condominiumId;
  final String guestName;
  final DateTime validityDate;
  final String qrData;
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
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        residentId,
        condominiumId,
        guestName,
        validityDate,
        qrData,
        status,
        createdAt,
        updatedAt,
      ];
}
