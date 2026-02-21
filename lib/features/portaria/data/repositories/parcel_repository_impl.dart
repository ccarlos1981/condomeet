import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/repositories/parcel_repository.dart';

class ParcelRepositoryImpl implements ParcelRepository {
  final List<Parcel> _mockParcels = [];

  @override
  Future<Result<void>> registerParcel(Parcel parcel) async {
    // Simulate local DB write (NFR2: < 100ms)
    await Future.delayed(const Duration(milliseconds: 50));
    
    _mockParcels.add(parcel);
    
    return const Success(null);
  }

  @override
  Future<Result<List<Parcel>>> getParcelsForResident(String residentId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final results = _mockParcels.where((p) => p.residentId == residentId).toList();
    return Success(results);
  }

  @override
  Future<Result<List<Parcel>>> getAllPendingParcels() async {
    await Future.delayed(const Duration(milliseconds: 50));
    final results = _mockParcels.where((p) => p.status == 'pending').toList();
    return Success(results);
  }

  @override
  Future<Result<void>> markAsDelivered(String parcelId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final index = _mockParcels.indexWhere((p) => p.id == parcelId);
    if (index != -1) {
      final oldParcel = _mockParcels[index];
      _mockParcels[index] = Parcel(
        id: oldParcel.id,
        residentId: oldParcel.residentId,
        residentName: oldParcel.residentName,
        unitNumber: oldParcel.unitNumber,
        block: oldParcel.block,
        arrivalTime: oldParcel.arrivalTime,
        photoUrl: oldParcel.photoUrl,
        status: 'delivered',
      );
    }
    return const Success(null);
  }

  @override
  Future<Result<List<Parcel>>> getParcelHistory({String? residentId}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final results = _mockParcels.where((p) {
      final isDelivered = p.status == 'delivered';
      final matchesResident = residentId == null || p.residentId == residentId;
      return isDelivered && matchesResident;
    }).toList();
    return Success(results);
  }
}
