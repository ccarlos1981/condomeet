
import 'dart:async';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/repositories/parcel_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/parcel.dart';

class ParcelRepositoryImpl implements ParcelRepository {
  final SupabaseClient _supabase;

  ParcelRepositoryImpl(this._supabase);

  /// Cache for unit resident IDs to avoid repeated lookups
  final Map<String, List<String>> _unitIdsCache = {};

  /// Looks up the user's bloco/apto from perfil, then returns all resident IDs
  /// sharing the same unit within the same condominium.
  Future<List<String>> _getUnitResidentIds(String residentId) async {
    if (residentId.isEmpty) return [];
    
    // Return cached value if available
    if (_unitIdsCache.containsKey(residentId)) {
      return _unitIdsCache[residentId]!;
    }
    
    // Step 1: Get the user's bloco, apto, and condominium
    final profile = await _supabase
        .from('perfil')
        .select('bloco_txt, apto_txt, condominio_id')
        .eq('id', residentId)
        .maybeSingle();
    if (profile == null) return [residentId];

    final bloco = profile['bloco_txt'] as String?;
    final apto = profile['apto_txt'] as String?;
    final condoId = profile['condominio_id'] as String?;
    if (bloco == null || apto == null || condoId == null) return [residentId];

    // Step 2: Get all resident IDs in the same unit
    final unitProfiles = await _supabase
        .from('perfil')
        .select('id')
        .eq('condominio_id', condoId)
        .eq('bloco_txt', bloco)
        .eq('apto_txt', apto);
    final ids = (unitProfiles as List).map((r) => r['id'] as String).toList();
    
    // Cache the result
    _unitIdsCache[residentId] = ids;
    return ids;
  }

  @override
  Future<Result<void>> registerParcel(Parcel parcel) async {
    try {
      final condoId = parcel.condominiumId ?? '';
      if (condoId.isEmpty) {
        return const Failure('Condomínio não identificado. Faça login novamente.');
      }

      // Use Supabase directly so the parcel is immediately visible to
      // all devices (residents + porters) without waiting for sync.
      await _supabase.from('encomendas').insert({
        'id': parcel.id,
        'resident_id': parcel.residentId,
        'condominio_id': condoId,
        'status': parcel.status,
        'arrival_time': parcel.arrivalTime.toIso8601String(),
        'photo_url': parcel.photoUrl,
        'tipo': parcel.tipo,
        'tracking_code': parcel.trackingCode,
        'observacao': parcel.observacao,
        'registered_by': parcel.registeredBy,
        'created_at': DateTime.now().toIso8601String(),
      });
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao registrar encomenda: $e');
    }
  }

  @override
  Future<Result<List<Parcel>>> getParcelsForResident(String residentId) async {
    if (residentId.isEmpty) return const Success([]);
    try {
      final unitIds = await _getUnitResidentIds(residentId);
      if (unitIds.isEmpty) return const Success([]);

      final rows = await _supabase
          .from('encomendas')
          .select('*, perfil!encomendas_resident_id_fkey(nome_completo, apto_txt, bloco_txt)')
          .inFilter('resident_id', unitIds)
          .order('arrival_time', ascending: false);

      return Success((rows as List).map((r) => _mapToParcel(r as Map<String, dynamic>)).toList());
    } catch (e) {
      return Failure('Erro ao buscar encomendas: $e');
    }
  }

  @override
  Stream<List<Parcel>> watchPendingParcelsForUnit(String residentId) {
    return Stream.fromIterable([0])
        .asyncExpand((_) async* {
          yield await _fetchPendingForUnit(residentId);
          await for (final _ in Stream.periodic(const Duration(seconds: 10))) {
            yield await _fetchPendingForUnit(residentId);
          }
        })
        .handleError((e) => print('❌ watchPendingParcelsForUnit error: $e'));
  }

  Future<List<Parcel>> _fetchPendingForUnit(String residentId) async {
    if (residentId.isEmpty) { print('⚠️ _fetchPendingForUnit: empty residentId'); return []; }
    final unitIds = await _getUnitResidentIds(residentId);
    print('📦 _fetchPendingForUnit: residentId=$residentId, unitIds=$unitIds');
    if (unitIds.isEmpty) { print('⚠️ _fetchPendingForUnit: no unitIds found'); return []; }

    final rows = await _supabase
        .from('encomendas')
        .select('*, perfil!encomendas_resident_id_fkey(nome_completo, apto_txt, bloco_txt)')
        .inFilter('resident_id', unitIds)
        .eq('status', 'pending')
        .order('arrival_time', ascending: false);
    print('📦 _fetchPendingForUnit: found ${(rows as List).length} parcels');
    return rows.map((r) => _mapToParcel(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<Result<List<Parcel>>> getAllPendingParcels(String condominiumId) async {
    if (condominiumId.isEmpty) return const Success([]);
    try {
      final rows = await _supabase
          .from('encomendas')
          .select('*, perfil!encomendas_resident_id_fkey(nome_completo, apto_txt, bloco_txt)')
          .eq('condominio_id', condominiumId)
          .eq('status', 'pending')
          .order('arrival_time', ascending: false);
      return Success((rows as List).map((r) => _mapToParcel(r as Map<String, dynamic>)).toList());
    } catch (e) {
      return Failure('Erro ao buscar encomendas pendentes: $e');
    }
  }

  @override
  Stream<List<Parcel>> watchAllPendingParcels(String condominiumId) {
    return Stream.fromIterable([0])
        .asyncExpand((_) async* {
          yield await _fetchAllPending(condominiumId);
          await for (final _ in Stream.periodic(const Duration(seconds: 10))) {
            yield await _fetchAllPending(condominiumId);
          }
        })
        .handleError((e) => print('❌ watchAllPendingParcels error: $e'));
  }

  Future<List<Parcel>> _fetchAllPending(String condominiumId) async {
    if (condominiumId.isEmpty) return [];
    final rows = await _supabase
        .from('encomendas')
        .select('*, perfil!encomendas_resident_id_fkey(nome_completo, apto_txt, bloco_txt)')
        .eq('condominio_id', condominiumId)
        .eq('status', 'pending')
        .order('arrival_time', ascending: false);
    return (rows as List).map((r) => _mapToParcel(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<Result<void>> markAsDelivered(
    String parcelId, {
    String? pickupProofUrl,
    String? pickedUpById,
    String? pickedUpByName,
  }) async {
    try {
      // Use Supabase directly — the porter device does not have cross-user
      // PowerSync records for parcels registered by other residents.
      await _supabase.from('encomendas').update({
        'status': 'delivered',
        'delivery_time': DateTime.now().toIso8601String(),
        'pickup_proof_url': pickupProofUrl,
        'picked_up_by_id': pickedUpById,
        'picked_up_by_name': pickedUpByName,
      }).eq('id', parcelId);
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
    if (condominiumId.isEmpty) return const Success([]);
    try {
      var query = _supabase
          .from('encomendas')
          .select('*, perfil!encomendas_resident_id_fkey(nome_completo, apto_txt, bloco_txt)')
          .eq('condominio_id', condominiumId)
          .eq('status', 'delivered');

      // If residentId is provided, resolve the unit and filter by all unit members
      if (residentId != null && residentId.isNotEmpty) {
        final unitIds = await _getUnitResidentIds(residentId);
        if (unitIds.isNotEmpty) {
          query = query.inFilter('resident_id', unitIds);
        }
      }

      final rows = await query.order('delivery_time', ascending: false);
      return Success((rows as List).map((r) => _mapToParcel(r as Map<String, dynamic>)).toList());
    } catch (e) {
      return Failure('Erro ao buscar histórico: $e');
    }
  }

  Parcel _mapToParcel(Map<String, dynamic> row) {
    // Handle Supabase join: perfil is a nested map
    final perfil = row['perfil'] as Map<String, dynamic>?;
    return Parcel(
      id: row['id'] as String,
      residentId: row['resident_id'] as String,
      residentName: perfil?['nome_completo'] as String? ?? row['nome_completo'] as String? ?? 'Residente Desconhecido',
      unitNumber: perfil?['apto_txt'] as String? ?? row['unit_number'] as String? ?? 'N/A',
      block: perfil?['bloco_txt'] as String? ?? row['block'] as String? ?? 'N/A',
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
