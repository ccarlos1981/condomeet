import 'dart:math';
import 'package:condomeet/core/errors/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:condomeet/features/access/domain/models/invitation.dart';
import 'package:condomeet/features/access/domain/repositories/invitation_repository.dart';

class InvitationRepositoryImpl implements InvitationRepository {
  final SupabaseClient _supabase;

  InvitationRepositoryImpl(this._supabase);

  @override
  Stream<List<Invitation>> watchInvitationsForResident(String residentId) {
    // Use Supabase polling so new invitations from the resident's device
    // appear immediately without waiting for PowerSync.
    return Stream.fromIterable([0])
        .asyncExpand((_) async* {
          yield await _fetchResidentInvitations(residentId);
          await for (final _ in Stream.periodic(const Duration(seconds: 10))) {
            yield await _fetchResidentInvitations(residentId);
          }
        })
        .handleError((e) => print('❌ watchInvitationsForResident error: $e'));
  }

  Future<List<Invitation>> _fetchResidentInvitations(String residentId) async {
    final rows = await _supabase
        .from('convites')
        .select()
        .eq('resident_id', residentId)
        .eq('status', 'active')
        .gte('validity_date', DateTime.now().toIso8601String())
        .order('created_at', ascending: false);
    return (rows as List).map((r) => _fromMap(r as Map<String, dynamic>)).toList();
  }

  @override
  Stream<List<Invitation>> watchAllActiveInvitations(String condominiumId) {
    return Stream.fromIterable([0])
        .asyncExpand((_) async* {
          yield await _fetchAllActiveInvitations(condominiumId);
          await for (final _ in Stream.periodic(const Duration(seconds: 10))) {
            yield await _fetchAllActiveInvitations(condominiumId);
          }
        })
        .handleError((e) => print('❌ watchAllActiveInvitations error: $e'));
  }

  Future<List<Invitation>> _fetchAllActiveInvitations(String condominiumId) async {
    final rows = await _supabase
        .from('convites')
        .select()
        .eq('condominio_id', condominiumId)
        .eq('status', 'active')
        .gte('validity_date', DateTime.now().toIso8601String())
        .order('validity_date');
    return (rows as List).map((r) => _fromMap(r as Map<String, dynamic>)).toList();
  }

  @override
  Stream<List<Invitation>> watchCondominiumInvitations({
    required String condominiumId,
    bool? liberado,
    String? codeFilter,
    String? blocoFilter,
    String? aptoFilter,
    String? dateFilter,
    int? limit,
  }) {
    // Use Supabase directly — PowerSync only holds data for the local user,
    // but the portaria needs to see invitations created by all residents.
    // Emit immediately, then every 5 seconds
    // (Stream.periodic starts AFTER first interval, so we prepend a tick=0)
    return Stream.fromIterable([0])
        .asyncExpand((_) async* {
          // First immediate load
          yield await _fetchCondominiumInvitations(
            condominiumId: condominiumId,
            liberado: liberado,
            codeFilter: codeFilter,
            blocoFilter: blocoFilter,
            aptoFilter: aptoFilter,
            dateFilter: dateFilter,
            limit: limit,
          );
          // Then poll every 5 seconds
          await for (final _ in Stream.periodic(const Duration(seconds: 15))) {
            yield await _fetchCondominiumInvitations(
              condominiumId: condominiumId,
              liberado: liberado,
              codeFilter: codeFilter,
              blocoFilter: blocoFilter,
              aptoFilter: aptoFilter,
              dateFilter: dateFilter,
              limit: limit,
            );
          }
        })
        .handleError((e) => print('❌ watchCondominiumInvitations error: $e'));
  }

  Future<List<Invitation>> _fetchCondominiumInvitations({
    required String condominiumId,
    bool? liberado,
    String? codeFilter,
    String? blocoFilter,
    String? aptoFilter,
    String? dateFilter,
    int? limit,
  }) async {
          var query = _supabase
              .from('convites')
              .select('''
                *,
                perfil!resident_id(
                  nome_completo,
                  bloco_txt,
                  apto_txt
                )
              ''')
              .eq('condominio_id', condominiumId);

          if (liberado != null) {
            query = query.eq('visitante_compareceu', liberado);
          }
          if (dateFilter != null && dateFilter.isNotEmpty) {
            query = query.gte('validity_date', dateFilter).lte('validity_date', '${dateFilter}T23:59:59');
          }

          var orderedQuery = query.order('created_at', ascending: false);
          if (limit != null) {
            orderedQuery = orderedQuery.limit(limit);
          }
          final response = await orderedQuery;
          final rows = response as List;
          return rows.map((row) {
            final Map<String, dynamic> flat = Map<String, dynamic>.from(row);
            // Flatten perfil join
            final perfil = row['perfil'] as Map<String, dynamic>?;
            if (perfil != null) {
              flat['resident_name'] = perfil['nome_completo'];
              flat['bloco_txt'] = perfil['bloco_txt'];
              flat['apto_txt'] = perfil['apto_txt'];
            }
            // Client-side filter for code/bloco/apto
            return flat;
          }).where((flat) {
            if (codeFilter != null && codeFilter.isNotEmpty) {
              if (!(flat['qr_data'] as String? ?? '').toUpperCase().contains(codeFilter.toUpperCase())) return false;
            }
            if (blocoFilter != null && blocoFilter.isNotEmpty) {
              if (!(flat['bloco_txt'] as String? ?? '').toUpperCase().contains(blocoFilter.toUpperCase())) return false;
            }
            if (aptoFilter != null && aptoFilter.isNotEmpty) {
              if (!(flat['apto_txt'] as String? ?? '').toUpperCase().contains(aptoFilter.toUpperCase())) return false;
            }
            return true;
          }).map((flat) => _fromMap(flat)).toList();
  }

  @override
  Future<Result<Invitation>> createInvitation({
    required String residentId,
    required String guestName,
    required DateTime validityDate,
    required String condominiumId,
    String? visitorType,
    String? visitorPhone,
    String? observation,
  }) async {
    try {
      final id = const Uuid().v4();
      // Generate random 3-char alphanumeric code
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final rng = Random();
      final shortCode = String.fromCharCodes(
        Iterable.generate(3, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
      );
      final qrData = shortCode;
      final now = DateTime.now();

      final invitation = Invitation(
        id: id,
        residentId: residentId,
        condominiumId: condominiumId,
        guestName: guestName,
        validityDate: validityDate,
        qrData: qrData,
        visitorType: visitorType,
        visitorPhone: visitorPhone,
        observation: observation,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      );

      // Use Supabase directly — PowerSync only holds local user data,
      // and invitations may not be synced to other devices immediately.
      await _supabase.from('convites').insert({
        'id': id,
        'resident_id': residentId,
        'condominio_id': condominiumId,
        'guest_name': guestName,
        'validity_date': validityDate.toIso8601String(),
        'qr_data': qrData,
        'visitor_type': visitorType,
        'visitor_phone': visitorPhone,
        'observation': observation,
        'status': 'active',
        'visitante_compareceu': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      return Success(invitation);
    } catch (e) {
      return Failure('Erro ao criar convite: ${e.toString()}');
    }
  }

  @override
  Future<Result<List<Invitation>>> getResidentInvitationsPaginated({
    required String residentId,
    required int limit,
    required int offset,
  }) async {
    try {
      final rows = await _supabase
          .from('convites')
          .select()
          .eq('resident_id', residentId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return Success((rows as List).map((r) => Invitation.fromMap(r as Map<String, dynamic>)).toList());
    } catch (e) {
      return Failure('Erro ao buscar convites: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> approveVisitorEntry({
    required String invitationId,
    required String porterId,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      // Use Supabase directly — PowerSync won't have cross-user records
      await _supabase.from('convites').update({
        'visitante_compareceu': true,
        'liberado_por': porterId,
        'liberado_em': now,
        'updated_at': now,
      }).eq('id', invitationId);
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao liberar visitante: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> markAsUsed(String invitationId) async {
    try {
      // Use Supabase directly — the porter device does not have cross-user
      // PowerSync records for invitations created by other residents.
      final now = DateTime.now().toIso8601String();
      await _supabase.from('convites').update({
        'status': 'used',
        'updated_at': now,
      }).eq('id', invitationId);
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao marcar convite como usado: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> cancelInvitation(String invitationId) async {
    try {
      await _supabase.from('convites').update({
        'status': 'expired',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', invitationId);
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao cancelar convite: ${e.toString()}');
    }
  }

  Invitation _fromMap(Map<String, dynamic> row) {
    return Invitation.fromMap(row);
  }
}
