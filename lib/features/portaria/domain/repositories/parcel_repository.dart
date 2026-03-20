import 'package:condomeet/core/errors/result.dart';
import '../entities/parcel.dart';

abstract class ParcelRepository {
  /// Registers a new parcel in the local database.
  Future<Result<void>> registerParcel(Parcel parcel);

  /// Fetches all parcels for a specific resident.
  Future<Result<List<Parcel>>> getParcelsForResident(String residentId);

  /// Watches pending parcels for the resident's unit (all members).
  Stream<List<Parcel>> watchPendingParcelsForUnit(String residentId);

  /// Fetches all pending parcels for the porter.
  Future<Result<List<Parcel>>> getAllPendingParcels(String condominiumId);

  /// Watches all pending parcels for the porter (real-time).
  Stream<List<Parcel>> watchAllPendingParcels(String condominiumId);

  /// Marks a parcel as delivered.
  Future<Result<void>> markAsDelivered(String parcelId, {
    String? pickupProofUrl,
    String? pickedUpById,
    String? pickedUpByName,
    bool silentDischarge = false,
    String? dischargedBy,
  });

  /// Fetches parcel history for the unit. If residentId is provided, resolves unit from profile.
  Future<Result<List<Parcel>>> getParcelHistory({String? residentId, required String condominiumId});
}
