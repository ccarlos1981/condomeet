import 'package:condomeet/core/errors/result.dart';

class Parcel {
  final String id;
  final String residentId;
  final String residentName;
  final String unitNumber;
  final String block;
  final DateTime arrivalTime;
  final String? photoUrl;
  final String status; // 'pending', 'delivered'

  Parcel({
    required this.id,
    required this.residentId,
    required this.residentName,
    required this.unitNumber,
    required this.block,
    required this.arrivalTime,
    this.photoUrl,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'resident_id': residentId,
      'resident_name': residentName,
      'unit_number': unitNumber,
      'block': block,
      'arrival_time': arrivalTime.toIso8601String(),
      'photo_url': photoUrl,
      'status': status,
    };
  }
}

abstract class ParcelRepository {
  /// Registers a new parcel in the local database.
  Future<Result<void>> registerParcel(Parcel parcel);

  /// Fetches all parcels for a specific resident.
  Future<Result<List<Parcel>>> getParcelsForResident(String residentId);

  /// Fetches all pending parcels for the porter.
  Future<Result<List<Parcel>>> getAllPendingParcels();

  /// Marks a parcel as delivered.
  Future<Result<void>> markAsDelivered(String parcelId);

  /// Fetches parcel history. If residentId is null, fetches all.
  Future<Result<List<Parcel>>> getParcelHistory({String? residentId});
}
