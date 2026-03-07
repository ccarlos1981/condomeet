import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';

class _FakeResidentRepository implements ResidentRepository {
  final List<Map<String, dynamic>> _data;

  _FakeResidentRepository(this._data);

  static String _normalize(String input) {
    const withAccents    = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
    const withoutAccents = 'aaaaaeeeeiiiioooooouuuucnAAAAEEEEIIIIOOOOOUUUUCN';
    var result = input.toLowerCase();
    for (var i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return result;
  }

  @override
  Future<Result<List<Resident>>> searchResidents(String query, String condominiumId) async {
    if (query.isEmpty) return const Success([]);

    final normalizedQuery = _normalize(query);

    final results = _data.where((row) {
      // 1. Isolation check
      if (row['condominium_id'] != condominiumId) return false;

      // 2. Fuzzy search logic
      final normalizedName = _normalize(row['full_name']);
      final unit = (row['unit_number'] ?? '').toString().toLowerCase();
      
      return normalizedName.contains(normalizedQuery) ||
             unit.contains(query.toLowerCase());
    }).map((row) => Resident.fromMap(row)).toList();

    return Success(results);
  }

  @override
  Future<Result<void>> requestSelfRegistration({
    required String name,
    required String block,
    required String unit,
    String? photoPath,
    String? condominiumId,
  }) async => const Success(null);

  @override
  Future<Result<List<Resident>>> getPendingResidents() async => const Success([]);

  @override
  Future<Result<void>> approveResident(String residentId) async => const Success(null);

  @override
  Future<Result<void>> rejectResident(String residentId) async => const Success(null);
}

void main() {
  final seedData = [
    {'id': '1', 'full_name': 'João Silva', 'unit_number': '101', 'block': 'A', 'condominium_id': 'condo-1', 'status': 'active'},
    {'id': '2', 'full_name': 'Maria Costa', 'unit_number': '501', 'block': 'B', 'condominium_id': 'condo-1', 'status': 'active'},
    {'id': '3', 'full_name': 'Carlos Souza', 'unit_number': '202', 'block': 'C', 'condominium_id': 'condo-2', 'status': 'active'}, // Different condo
  ];

  late ResidentRepository repository;

  setUp(() {
    repository = _FakeResidentRepository(seedData);
  });

  group('ResidentRepository — searchResidents (Epic 2 Security & Fuzzy)', () {
    test('filters by condominiumId (Isolation)', () async {
      // Search for 'Silva' in condo-2 (where only 'Souza' exists)
      final result = await repository.searchResidents('Silva', 'condo-2');
      expect((result as Success<List<Resident>>).data, isEmpty);

      // Search for 'Silva' in condo-1
      final resultOk = await repository.searchResidents('Silva', 'condo-1');
      expect((resultOk as Success<List<Resident>>).data.length, 1);
    });

    test('AC3 — fuzzy: "Joao" finds "João Silva"', () async {
      final result = await repository.searchResidents('Joao', 'condo-1');
      final residents = (result as Success<List<Resident>>).data;
      expect(residents.first.fullName, 'João Silva');
    });

    test('finds resident by unit number', () async {
      final result = await repository.searchResidents('501', 'condo-1');
      final residents = (result as Success<List<Resident>>).data;
      expect(residents.first.unitNumber, '501');
    });
  });
}
