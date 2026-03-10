
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/repositories/parcel_repository.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import '../../domain/entities/parcel.dart';

class ParcelRepositoryImpl implements ParcelRepository {
  final PowerSyncService _powerSync;

  ParcelRepositoryImpl(this._powerSync);

  @override
  Future<Result<void>> registerParcel(Parcel parcel) async {
    try {
      final condoId = parcel.condominiumId ?? '';
      if (condoId.isEmpty) {
        return const Failure('Condomínio não identificado. Faça login novamente.');
      }

      await _powerSync.db.execute(
        '''INSERT INTO encomendas 
          (id, resident_id, condominio_id, status, arrival_time, 
           photo_url, tipo, tracking_code, observacao, registered_by, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          parcel.id,
          parcel.residentId,
          condoId,
          parcel.status,
          parcel.arrivalTime.toIso8601String(),
          parcel.photoUrl,
          parcel.tipo,
          parcel.trackingCode,
          parcel.observacao,
          parcel.registeredBy,
          DateTime.now().toIso8601String(),
        ],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao registrar encomenda: $e');
    }
  }

  @override
  Future<Result<List<Parcel>>> getParcelsForResident(String residentId) async {
    try {
      final results = await _powerSync.db.getAll(
        '''SELECT p.*, prof.nome_completo, prof.apto_txt as unit_number, prof.bloco_txt as block 
           FROM encomendas p
           LEFT JOIN perfil prof ON p.resident_id = prof.id
           WHERE p.resident_id = ? 
           ORDER BY p.arrival_time DESC''',
        [residentId],
      );
      return Success(results.map((row) => _mapToParcel(row)).toList());
    } catch (e) {
      return Failure('Erro ao buscar encomendas: $e');
    }
  }

  @override
  Stream<List<Parcel>> watchPendingParcelsForResident(String residentId) {
    return _powerSync.db.watch(
      '''SELECT p.*, prof.nome_completo, prof.apto_txt as unit_number, prof.bloco_txt as block 
         FROM encomendas p
         LEFT JOIN perfil prof ON p.resident_id = prof.id
         WHERE p.resident_id = ? AND p.status = 'pending'
         ORDER BY p.arrival_time DESC''',
      parameters: [residentId],
    ).map((results) => results.map((row) => _mapToParcel(row)).toList());
  }

  @override
  Future<Result<List<Parcel>>> getAllPendingParcels(String condominiumId) async {
    try {
      final results = await _powerSync.db.getAll(
        '''SELECT p.*, prof.nome_completo, prof.apto_txt as unit_number, prof.bloco_txt as block 
           FROM encomendas p
           LEFT JOIN perfil prof ON p.resident_id = prof.id
           WHERE p.status = 'pending' AND p.condominio_id = ?
           ORDER BY p.arrival_time DESC''',
        [condominiumId],
      );
      return Success(results.map((row) => _mapToParcel(row)).toList());
    } catch (e) {
      return Failure('Erro ao buscar encomendas pendentes: $e');
    }
  }

  @override
  Stream<List<Parcel>> watchAllPendingParcels(String condominiumId) {
    return _powerSync.db.watch(
      '''SELECT p.*, prof.nome_completo, prof.apto_txt as unit_number, prof.bloco_txt as block 
         FROM encomendas p
         LEFT JOIN perfil prof ON p.resident_id = prof.id
         WHERE p.status = 'pending' AND p.condominio_id = ?
         ORDER BY p.arrival_time DESC''',
      parameters: [condominiumId],
    ).map((results) => results.map((row) => _mapToParcel(row)).toList());
  }

  @override
  Future<Result<void>> markAsDelivered(
    String parcelId, {
    String? pickupProofUrl,
    String? pickedUpById,
    String? pickedUpByName,
  }) async {
    try {
      await _powerSync.db.execute(
        '''UPDATE encomendas 
           SET status = ?, delivery_time = ?, pickup_proof_url = ?,
               picked_up_by_id = ?, picked_up_by_name = ?
           WHERE id = ?''',
        [
          'delivered',
          DateTime.now().toIso8601String(),
          pickupProofUrl,
          pickedUpById,
          pickedUpByName,
          parcelId,
        ],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao marcar como entregue: $e');
    }
  }

  @override
  Future<Result<List<Parcel>>> getParcelHistory({
    String? residentId,
    required String condominiumId,
  }) async {
    try {
      String query = '''
        SELECT p.*, prof.nome_completo, prof.apto_txt as unit_number, prof.bloco_txt as block 
        FROM encomendas p
        LEFT JOIN perfil prof ON p.resident_id = prof.id
        WHERE p.status = 'delivered' AND p.condominio_id = ?
      ''';
      List<String> args = [condominiumId];

      if (residentId != null) {
        query += ' AND p.resident_id = ?';
        args.add(residentId);
      }

      query += ' ORDER BY p.delivery_time DESC';

      final results = await _powerSync.db.getAll(query, args);
      return Success(results.map((row) => _mapToParcel(row)).toList());
    } catch (e) {
      return Failure('Erro ao buscar histórico: $e');
    }
  }

  Parcel _mapToParcel(Map<String, dynamic> row) {
    return Parcel(
      id: row['id'] as String,
      residentId: row['resident_id'] as String,
      residentName: row['nome_completo'] as String? ?? 'Residente Desconhecido',
      unitNumber: row['unit_number'] as String? ?? 'N/A',
      block: row['block'] as String? ?? 'N/A',
      arrivalTime: DateTime.parse(row['arrival_time'] as String),
      deliveryTime: row['delivery_time'] != null
          ? DateTime.parse(row['delivery_time'] as String)
          : null,
      photoUrl: row['photo_url'] as String?,
      pickupProofUrl: row['pickup_proof_url'] as String?,
      status: row['status'] as String,
      condominiumId: row['condominio_id'] as String?,
      tipo: row['tipo'] as String?,
      trackingCode: row['tracking_code'] as String?,
      observacao: row['observacao'] as String?,
      registeredBy: row['registered_by'] as String?,
      pickedUpById: row['picked_up_by_id'] as String?,
      pickedUpByName: row['picked_up_by_name'] as String?,
    );
  }
}
