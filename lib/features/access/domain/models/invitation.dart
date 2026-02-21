import 'package:equatable/equatable.dart';

class Invitation extends Equatable {
  final String id;
  final String residentId;
  final String guestName;
  final DateTime validityDate;
  final String qrData;
  final String status; // 'active', 'used', 'expired'

  const Invitation({
    required this.id,
    required this.residentId,
    required this.guestName,
    required this.validityDate,
    required this.qrData,
    this.status = 'active',
  });

  @override
  List<Object?> get props => [id, residentId, guestName, validityDate, qrData, status];
}
