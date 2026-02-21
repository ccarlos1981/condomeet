import 'package:condomeet/core/errors/result.dart';

class Resident {
  final String id;
  final String fullName;
  final String? unitNumber;
  final String? block;
  final String? avatarUrl;

  Resident({
    required this.id,
    required this.fullName,
    this.unitNumber,
    this.block,
    this.avatarUrl,
  });

  factory Resident.fromMap(Map<String, dynamic> map) {
    return Resident(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      unitNumber: map['unit_number'] as String?,
      block: map['block'] as String?,
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}

abstract class ResidentRepository {
  /// Searches for residents in the local database matching the query (name or unit).
  Future<Result<List<Resident>>> searchResidents(String query);

  /// Requests self-registration for a new resident.
  Future<Result<void>> requestSelfRegistration({
    required String name,
    required String block,
    required String unit,
    String? photoPath,
  });

  /// Fetches residents awaiting approval.
  Future<Result<List<Resident>>> getPendingResidents();

  /// Approves a pending resident.
  Future<Result<void>> approveResident(String residentId);

  /// Rejects/Deletes a pending resident request.
  Future<Result<void>> rejectResident(String residentId);
}
