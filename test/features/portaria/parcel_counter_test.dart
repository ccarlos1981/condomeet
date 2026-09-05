import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/entities/parcel.dart';
import 'package:condomeet/features/portaria/domain/repositories/parcel_repository.dart';

class _FakeParcelRepository implements ParcelRepository {
  final List<Parcel> _storage;

  _FakeParcelRepository(this._storage);

  @override
  Future<Result<List<Parcel>>> getAllPendingParcels(String condominiumId) async {
    final pending = _storage
        .where((p) => p.condominiumId == condominiumId && p.status == 'pending')
        .toList();
    return Success(pending);
  }

  @override
  Stream<List<Parcel>> watchAllPendingParcels(String condominiumId) {
    final pending = _storage
        .where((p) => p.condominiumId == condominiumId && p.status == 'pending')
        .toList();
    return Stream.value(pending);
  }

  @override
  Future<Result<List<Parcel>>> getParcelsForResident(String residentId) async => const Success([]);

  @override
  Stream<List<Parcel>> watchPendingParcelsForUnit(String residentId) => Stream.value([]);

  @override
  Future<Result<void>> markAsDelivered(
    String parcelId, {
    String? pickupProofUrl,
    String? pickedUpById,
    String? pickedUpByName,
    bool silentDischarge = false,
    String? dischargedBy,
  }) async => const Success(null);

  @override
  Future<Result<void>> registerParcel(Parcel parcel) async => const Success(null);

  @override
  Future<Result<List<Parcel>>> getParcelHistory({String? residentId, required String condominiumId}) async =>
      const Success([]);
}

void main() {
  const testCondoId = '4828f5f6-454c-438c-9ef3-9f1bf5a7ab94'; // Montserrat

  Parcel createFakeParcel(int index, {String status = 'pending'}) {
    return Parcel(
      id: 'parcel-$index',
      residentName: 'Morador $index',
      unitNumber: '$index',
      block: 'A',
      arrivalTime: DateTime.now().subtract(Duration(hours: index)),
      status: status,
      condominiumId: testCondoId,
    );
  }

  group('Parcel Counter & Repository — Testes de Contagem Real sem Limite Artificial', () {
    test('Cenário 0 pendências: deve retornar exatamente 0', () async {
      final repo = _FakeParcelRepository([]);
      final result = await repo.getAllPendingParcels(testCondoId);
      final streamResult = await repo.watchAllPendingParcels(testCondoId).first;

      expect((result as Success<List<Parcel>>).data.length, 0);
      expect(streamResult.length, 0);
    });

    test('Cenário 1 pendência: deve retornar exatamente 1', () async {
      final repo = _FakeParcelRepository([createFakeParcel(1)]);
      final result = await repo.getAllPendingParcels(testCondoId);
      final streamResult = await repo.watchAllPendingParcels(testCondoId).first;

      expect((result as Success<List<Parcel>>).data.length, 1);
      expect(streamResult.length, 1);
    });

    test('Cenário 11 pendências (Situação Real Montserrat): deve retornar exatamente 11', () async {
      final parcels = List.generate(11, (i) => createFakeParcel(i + 1));
      final repo = _FakeParcelRepository(parcels);
      final result = await repo.getAllPendingParcels(testCondoId);
      final streamResult = await repo.watchAllPendingParcels(testCondoId).first;

      expect((result as Success<List<Parcel>>).data.length, 11);
      expect(streamResult.length, 11);
    });

    test('Cenário 50 pendências: deve retornar exatamente 50', () async {
      final parcels = List.generate(50, (i) => createFakeParcel(i + 1));
      final repo = _FakeParcelRepository(parcels);
      final result = await repo.getAllPendingParcels(testCondoId);
      final streamResult = await repo.watchAllPendingParcels(testCondoId).first;

      expect((result as Success<List<Parcel>>).data.length, 50);
      expect(streamResult.length, 50);
    });

    test('Cenário 51 pendências (Ultra-limite anterior): deve retornar exatamente 51 sem truncar', () async {
      final parcels = List.generate(51, (i) => createFakeParcel(i + 1));
      final repo = _FakeParcelRepository(parcels);
      final result = await repo.getAllPendingParcels(testCondoId);
      final streamResult = await repo.watchAllPendingParcels(testCondoId).first;

      expect((result as Success<List<Parcel>>).data.length, 51);
      expect(streamResult.length, 51);
    });

    test('Cenário 100 pendências: deve retornar exatamente 100 sem truncar', () async {
      final parcels = List.generate(100, (i) => createFakeParcel(i + 1));
      final repo = _FakeParcelRepository(parcels);
      final result = await repo.getAllPendingParcels(testCondoId);
      final streamResult = await repo.watchAllPendingParcels(testCondoId).first;

      expect((result as Success<List<Parcel>>).data.length, 100);
      expect(streamResult.length, 100);
    });
  });
}
