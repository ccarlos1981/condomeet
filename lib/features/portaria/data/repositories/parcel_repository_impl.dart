
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/repositories/parcel_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/parcel.dart';

class _UnitInfo {
  final String? condoId;
  final String? bloco;
  final String? apto;
  final List<String> unitResidentIds;
  final bool isAdminOrUnassigned;

  const _UnitInfo({
    required this.condoId,
    required this.bloco,
    required this.apto,
    required this.unitResidentIds,
    required this.isAdminOrUnassigned,
  });
}

class ParcelRepositoryImpl implements ParcelRepository {
  final SupabaseClient _supabase;

  ParcelRepositoryImpl(this._supabase);

  /// Cache for unit info to avoid repeated lookups
  final Map<String, _UnitInfo> _unitInfoCache = {};

  Future<_UnitInfo?> _getUnitInfo(String residentId) async {
    final cleanId = residentId.trim();
    if (cleanId.isEmpty) return null;
    if (_unitInfoCache.containsKey(cleanId)) {
      return _unitInfoCache[cleanId];
    }

    try {
      final profile = await _supabase
          .from('perfil')
          .select('bloco_txt, apto_txt, condominio_id')
          .eq('id', cleanId)
          .maybeSingle();

      if (profile == null) {
        final info = _UnitInfo(
          condoId: null,
          bloco: null,
          apto: null,
          unitResidentIds: [cleanId],
          isAdminOrUnassigned: true,
        );
        _unitInfoCache[cleanId] = info;
        return info;
      }

      final rawBloco = profile['bloco_txt'] as String?;
      final rawApto = profile['apto_txt'] as String?;
      final condoId = profile['condominio_id'] as String?;

      final bloco = rawBloco?.trim();
      final apto = rawApto?.trim();

      // Tratar contas administrativas com bloco_txt = '0' ou apto_txt = '0'
      // ou valores vazios:
      final isAdminOrUnassigned = bloco == null ||
          apto == null ||
          bloco.isEmpty ||
          apto.isEmpty ||
          bloco == '0' ||
          apto == '0';

      if (isAdminOrUnassigned || condoId == null || condoId.isEmpty) {
        final info = _UnitInfo(
          condoId: condoId,
          bloco: bloco,
          apto: apto,
          unitResidentIds: [cleanId],
          isAdminOrUnassigned: true,
        );
        _unitInfoCache[cleanId] = info;
        return info;
      }

      // Unidade residencial válida: busca os moradores da mesma unidade
      final unitProfiles = await _supabase
          .from('perfil')
          .select('id')
          .eq('condominio_id', condoId)
          .eq('bloco_txt', rawBloco!)
          .eq('apto_txt', rawApto!);

      final ids = (unitProfiles as List)
          .map((r) => r['id'] as String)
          .where((id) => id.isNotEmpty)
          .toList();

      if (!ids.contains(cleanId)) {
        ids.add(cleanId);
      }

      final info = _UnitInfo(
        condoId: condoId,
        bloco: rawBloco,
        apto: rawApto,
        unitResidentIds: ids,
        isAdminOrUnassigned: false,
      );
      _unitInfoCache[cleanId] = info;
      return info;
    } catch (e) {
      debugPrint('⚠️ Error resolving unit info for $cleanId: $e');
      return _UnitInfo(
        condoId: null,
        bloco: null,
        apto: null,
        unitResidentIds: [cleanId],
        isAdminOrUnassigned: true,
      );
    }
  }

  /// Looks up the user's bloco/apto from perfil, then returns all resident IDs
  /// sharing the same unit within the same condominium.
  @visibleForTesting
  Future<List<String>> getUnitResidentIds(String residentId) async {
    final info = await _getUnitInfo(residentId);
    return info?.unitResidentIds ?? (residentId.trim().isNotEmpty ? [residentId.trim()] : []);
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
        'arrival_time': parcel.arrivalTime.toUtc().toIso8601String(),
        'photo_url': parcel.photoUrl,
        'tipo': parcel.tipo,
        'tracking_code': parcel.trackingCode,
        'observacao': parcel.observacao,
        'registered_by': parcel.registeredBy,
        'bloco': parcel.block,
        'apto': parcel.unitNumber,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao registrar encomenda: $e');
    }
  }

  @override
  Future<Result<List<Parcel>>> getParcelsForResident(String residentId) async {
    final cleanId = residentId.trim();
    if (cleanId.isEmpty) return const Success([]);
    try {
      final unitInfo = await _getUnitInfo(cleanId);
      if (unitInfo == null) return const Success([]);

      var query = _supabase
          .from('encomendas')
          .select('*, perfil!encomendas_resident_id_fkey(nome_completo,apto_txt,bloco_txt)');

      if (unitInfo.condoId != null && unitInfo.condoId!.isNotEmpty) {
        query = query.eq('condominio_id', unitInfo.condoId!);
      }

      if (unitInfo.isAdminOrUnassigned) {
        query = query.eq('resident_id', cleanId);
      } else {
        final idsFilter = unitInfo.unitResidentIds.isNotEmpty
            ? 'resident_id.in.(${unitInfo.unitResidentIds.join(",")})'
            : 'resident_id.eq.$cleanId';
        final blockAptoFilter = 'and(bloco.eq.${unitInfo.bloco},apto.eq.${unitInfo.apto})';
        query = query.or('$idsFilter,$blockAptoFilter');
      }

      final rows = await query.order('created_at', ascending: false);
      return Success((rows as List).map((r) => _mapToParcel(r as Map<String, dynamic>)).toList());
    } catch (e) {
      return Failure('Erro ao buscar encomendas: $e');
    }
  }

  @override
  Stream<List<Parcel>> watchPendingParcelsForUnit(String residentId) {
    final cleanId = residentId.trim();
    if (cleanId.isEmpty) {
      return Stream.value(<Parcel>[]);
    }
    return Stream.fromIterable([0])
        .asyncExpand((_) async* {
          try {
            yield await _fetchPendingForUnit(cleanId);
          } catch (e) {
            debugPrint('⚠️ watchPendingParcelsForUnit: initial fetch error: $e');
            yield <Parcel>[];
          }
          await for (final _ in Stream.periodic(const Duration(seconds: 10))) {
            try {
              yield await _fetchPendingForUnit(cleanId);
            } catch (e) {
              debugPrint('⚠️ watchPendingParcelsForUnit: polling error: $e');
              yield <Parcel>[];
            }
          }
        });
  }

  Future<List<Parcel>> _fetchPendingForUnit(String residentId) async {
    final cleanId = residentId.trim();
    if (cleanId.isEmpty) return [];
    final unitInfo = await _getUnitInfo(cleanId);
    if (unitInfo == null) return [];

    var query = _supabase
        .from('encomendas')
        .select('*, perfil!encomendas_resident_id_fkey(nome_completo,apto_txt,bloco_txt)')
        .eq('status', 'pending');

    if (unitInfo.condoId != null && unitInfo.condoId!.isNotEmpty) {
      query = query.eq('condominio_id', unitInfo.condoId!);
    }

    if (unitInfo.isAdminOrUnassigned) {
      // Para conta administrativa: usar estritamente resident_id = residentId
      // NÃO usar bloco/apto "0" como critério amplo.
      query = query.eq('resident_id', cleanId);
    } else {
      // Para unidade residencial válida:
      // filtrar por: condominio_id AND status = pending AND (
      //   resident_id pertencente à unidade OR bloco/apto correspondentes à unidade
      // )
      final idsFilter = unitInfo.unitResidentIds.isNotEmpty
          ? 'resident_id.in.(${unitInfo.unitResidentIds.join(",")})'
          : 'resident_id.eq.$cleanId';
      final blockAptoFilter = 'and(bloco.eq.${unitInfo.bloco},apto.eq.${unitInfo.apto})';
      query = query.or('$idsFilter,$blockAptoFilter');
    }

    final rows = await query
        .order('created_at', ascending: false)
        .limit(10);
    return (rows as List).map((r) => _mapToParcel(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<Result<List<Parcel>>> getAllPendingParcels(String condominiumId) async {
    if (condominiumId.isEmpty) return const Success([]);
    try {
      final rows = await _supabase
          .from('encomendas')
          .select('*, perfil!encomendas_resident_id_fkey(nome_completo,apto_txt,bloco_txt)')
          .eq('condominio_id', condominiumId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return Success((rows as List).map((r) => _mapToParcel(r as Map<String, dynamic>)).toList());
    } catch (e) {
      return Failure('Erro ao buscar encomendas pendentes: $e');
    }
  }

  @override
  Stream<List<Parcel>> watchAllPendingParcels(String condominiumId) {
    return Stream.fromIterable([0])
        .asyncExpand((_) async* {
          try {
            yield await _fetchAllPending(condominiumId);
          } catch (e) {
            debugPrint('⚠️ watchAllPendingParcels: initial fetch error: $e');
            yield <Parcel>[];
          }
          await for (final _ in Stream.periodic(const Duration(seconds: 10))) {
            try {
              yield await _fetchAllPending(condominiumId);
            } catch (e) {
              debugPrint('⚠️ watchAllPendingParcels: polling error: $e');
              yield <Parcel>[];
            }
          }
        });
  }

  Future<List<Parcel>> _fetchAllPending(String condominiumId) async {
    if (condominiumId.isEmpty) return [];
    final rows = await _supabase
        .from('encomendas')
        .select('*, perfil!encomendas_resident_id_fkey(nome_completo,apto_txt,bloco_txt)')
        .eq('condominio_id', condominiumId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (rows as List).map((r) => _mapToParcel(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<Result<void>> markAsDelivered(
    String parcelId, {
    String? pickupProofUrl,
    String? pickedUpById,
    String? pickedUpByName,
    bool silentDischarge = false,
    String? dischargedBy,
  }) async {
    try {
      // Use Supabase directly — the porter device does not have cross-user
      // PowerSync records for parcels registered by other residents.
      final updateData = <String, dynamic>{
        'status': 'delivered',
        // delivery_time is set server-side by DB trigger (fn_set_delivery_time)
        'pickup_proof_url': pickupProofUrl,
        'picked_up_by_id': pickedUpById,
        'picked_up_by_name': pickedUpByName,
      };
      if (silentDischarge) updateData['silent_discharge'] = true;
      if (dischargedBy != null) updateData['discharged_by'] = dischargedBy;
      await _supabase.from('encomendas').update(updateData).eq('id', parcelId);
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao marcar como entregue: $e');
    }
  }

  @override
  Future<Result<void>> cancelParcel(String parcelId, {String? reason}) async {
    try {
      final response = await _supabase.rpc('cancel_encomenda', params: {
        'p_encomenda_id': parcelId,
        'p_reason': reason ?? 'REGISTERED_BY_MISTAKE',
      });

      if (response is Map) {
        final success = response['success'] as bool? ?? false;
        if (!success) {
          final message = response['message'] as String? ?? 'Erro ao cancelar encomenda.';
          return Failure(message);
        }
      } else if (response is String) {
        if (response.contains('ALREADY_CANCELLED')) {
          return const Failure('Esta encomenda já foi cancelada anteriormente.');
        }
        if (response.contains('ALREADY_DELIVERED')) {
          return const Failure('Não é possível cancelar uma encomenda que já foi entregue.');
        }
        if (response.contains('NOT_FOUND')) {
          return const Failure('Encomenda não encontrada.');
        }
        if (response.contains('INVALID_STATUS') || response.contains('CONCURRENT_CONFLICT')) {
          return Failure('Conflito ao cancelar encomenda: $response');
        }
      }
      return const Success(null);
    } catch (e) {
      debugPrint('[ParcelRepositoryImpl] Erro ao cancelar encomenda: $e');
      return Failure('Erro ao cancelar encomenda: $e');
    }
  }

  @override
  Future<Result<List<Parcel>>> getParcelHistory({
    String? residentId,
    required String condominiumId,
  }) async {
    // Regra Inviolável: se residentId vazio/null -> return Success([])
    // NUNCA permitir fallback para consulta irrestrita do condomínio.
    if (residentId == null || residentId.trim().isEmpty) {
      return const Success([]);
    }
    if (condominiumId.isEmpty) {
      return const Success([]);
    }

    try {
      final cleanResidentId = residentId.trim();
      final unitInfo = await _getUnitInfo(cleanResidentId);

      var query = _supabase
          .from('encomendas')
          .select('*, perfil!encomendas_resident_id_fkey(nome_completo,apto_txt,bloco_txt)')
          .eq('condominio_id', condominiumId)
          .eq('status', 'delivered');

      if (unitInfo == null || unitInfo.isAdminOrUnassigned) {
        // Conta administrativa ou sem unidade: estritamente o próprio resident_id
        query = query.eq('resident_id', cleanResidentId);
      } else {
        // Unidade residencial válida: busca por moradores da unidade ou bloco/apto da unidade
        final idsFilter = unitInfo.unitResidentIds.isNotEmpty
            ? 'resident_id.in.(${unitInfo.unitResidentIds.join(",")})'
            : 'resident_id.eq.$cleanResidentId';
        final blockAptoFilter = 'and(bloco.eq.${unitInfo.bloco},apto.eq.${unitInfo.apto})';
        query = query.or('$idsFilter,$blockAptoFilter');
      }

      final rows = await query.order('delivery_time', ascending: false).limit(200);
      return Success((rows as List).map((r) => _mapToParcel(r as Map<String, dynamic>)).toList());
    } catch (e) {
      return Failure('Erro ao buscar histórico: $e');
    }
  }

  Parcel _mapToParcel(Map<String, dynamic> row) {
    // perfil join: may be null (no resident), a Map, or occasionally a List
    final raw = row['perfil'];
    final perfil = (raw is Map) ? raw as Map<String, dynamic> : null;

    // Prefer denormalized bloco/apto stored on the encomenda; fall back to perfil
    final bloco = (row['bloco'] as String?)?.isNotEmpty == true
        ? row['bloco'] as String
        : (perfil?['bloco_txt'] as String?) ?? '?';
    final apto = (row['apto'] as String?)?.isNotEmpty == true
        ? row['apto'] as String
        : (perfil?['apto_txt'] as String?) ?? '?';

    return Parcel(
      id: row['id'] as String? ?? '',
      residentId: row['resident_id'] as String?,
      residentName: (perfil?['nome_completo'] as String?) ?? 'Sem morador',
      unitNumber: apto,
      block: bloco,
      arrivalTime: row['arrival_time'] != null
          ? DateTime.tryParse(row['arrival_time'] as String) ?? DateTime.now()
          : DateTime.now(),
      deliveryTime: row['delivery_time'] != null
          ? DateTime.tryParse(row['delivery_time'] as String)
          : null,
      photoUrl: row['photo_url'] as String?,
      pickupProofUrl: row['pickup_proof_url'] as String?,
      status: row['status'] as String? ?? 'pending',
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
