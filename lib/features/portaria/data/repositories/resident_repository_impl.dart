import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';

class ResidentRepositoryImpl implements ResidentRepository {
  // Mock data for visual validation
  final List<Resident> _mockResidents = [
    Resident(id: '1', fullName: 'Cristiano Carlos', unitNumber: '101', block: 'A'),
    Resident(id: '2', fullName: 'Ana Silva', unitNumber: '102', block: 'A'),
    Resident(id: '3', fullName: 'João Pereira', unitNumber: '201', block: 'B'),
    Resident(id: '4', fullName: 'Maria Oliveira', unitNumber: '202', block: 'B'),
    Resident(id: '5', fullName: 'Felipe Santos', unitNumber: '301', block: 'C'),
    Resident(id: '6', fullName: 'Carla Souza', unitNumber: '302', block: 'C'),
    Resident(id: '7', fullName: 'Roberto Lima', unitNumber: '401', block: 'D'),
    Resident(id: '8', fullName: 'Joana Darque', unitNumber: '402', block: 'D'),
  ];

  @override
  Future<Result<List<Resident>>> searchResidents(String query) async {
    // Simulate short network/local delay (NFR2: < 100ms)
    await Future.delayed(const Duration(milliseconds: 50));

    if (query.isEmpty) {
      return const Success([]);
    }

    final sanitizedQuery = query.toLowerCase();
    final results = _mockResidents.where((resident) {
      final nameMatches = resident.fullName.toLowerCase().contains(sanitizedQuery);
      final unitMatches = resident.unitNumber?.contains(sanitizedQuery) ?? false;
      return nameMatches || unitMatches;
    }).toList();

    return Success(results);
  }

  @override
  Future<Result<void>> requestSelfRegistration({
    required String name,
    required String block,
    required String unit,
    String? photoPath,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // In a real app, this would save to a 'pending_residents' table or similar.
    return const Success(null);
  }

  @override
  Future<Result<List<Resident>>> getPendingResidents() async {
    await Future.delayed(const Duration(milliseconds: 50));
    // Simulated pending registration
    return Success([
      Resident(
        id: 'pend1',
        fullName: 'Cristiano Carlos',
        unitNumber: '501',
        block: 'B',
      ),
      Resident(
        id: 'pend2',
        fullName: 'Felipe Martins',
        unitNumber: '1202',
        block: 'A',
      ),
    ]);
  }

  @override
  Future<Result<void>> approveResident(String residentId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const Success(null);
  }

  @override
  Future<Result<void>> rejectResident(String residentId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const Success(null);
  }
}
