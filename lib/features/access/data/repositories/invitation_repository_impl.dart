import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:condomeet/features/access/domain/models/invitation.dart';
import 'package:condomeet/features/access/domain/repositories/invitation_repository.dart';

class InvitationRepositoryImpl implements InvitationRepository {
  final PowerSyncService _powerSync;
  final SupabaseClient _supabase;

  InvitationRepositoryImpl(this._powerSync, this._supabase);

  @override
  Stream<List<Invitation>> watchInvitationsForResident(String residentId) {
    return _powerSync.db.watch(
      "SELECT * FROM convites WHERE resident_id = ? AND status = 'active' AND validity_date >= CURRENT_TIMESTAMP ORDER BY created_at DESC",
      parameters: [residentId],
    ).map((rows) => rows.map((row) => _fromMap(row)).toList());
  }

  @override
  Stream<List<Invitation>> watchAllActiveInvitations(String condominiumId) {
    return _powerSync.db.watch(
      "SELECT * FROM convites WHERE condominio_id = ? AND status = 'active' AND validity_date >= CURRENT_TIMESTAMP ORDER BY validity_date ASC",
      parameters: [condominiumId],
    ).map((rows) => rows.map((row) => _fromMap(row)).toList());
  }

  @override
  Stream<List<Invitation>> watchCondominiumInvitations({
    required String condominiumId,
    bool? liberado,
    String? codeFilter,
    String? blocoFilter,
    String? aptoFilter,
    String? dateFilter,
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
          );
          // Then poll every 5 seconds
          await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
            yield await _fetchCondominiumInvitations(
              condominiumId: condominiumId,
              liberado: liberado,
              codeFilter: codeFilter,
              blocoFilter: blocoFilter,
              aptoFilter: aptoFilter,
              dateFilter: dateFilter,
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
            // visitante_compareceu is INTEGER (0/1) in Supabase — not boolean
            query = query.eq('visitante_compareceu', liberado ? 1 : 0);
          }
          if (dateFilter != null && dateFilter.isNotEmpty) {
            query = query.gte('validity_date', dateFilter).lte('validity_date', '${dateFilter}T23:59:59');
          }

          final response = await query.order('created_at', ascending: false);
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
      final qrData = 'condomeet_inv_${id.substring(0, 8)}';
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

      await _powerSync.db.execute(
        '''INSERT INTO convites (
            id, resident_id, condominio_id, guest_name, validity_date, 
            qr_data, visitor_type, visitor_phone, observation, 
            status, visitante_compareceu, created_at, updated_at
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          id,
          residentId,
          condominiumId,
          guestName,
          validityDate.toIso8601String(),
          qrData,
          visitorType,
          visitorPhone,
          observation,
          'active',
          0,
          now.toIso8601String(),
          now.toIso8601String()
        ],
      );

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
      final List<Map<String, dynamic>> results = await _powerSync.db.getAll(
        '''
        SELECT * FROM convites 
        WHERE resident_id = ? 
        ORDER BY created_at DESC 
        LIMIT ? OFFSET ?
        ''',
        [residentId, limit, offset],
      );

      final invitations = results.map((row) => Invitation.fromMap(row)).toList();
      return Success(invitations);
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
      await _powerSync.db.execute(
        "UPDATE convites SET status = 'used', updated_at = ? WHERE id = ?",
        [DateTime.now().toIso8601String(), invitationId],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao marcar convite como usado: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> cancelInvitation(String invitationId) async {
    try {
      await _powerSync.db.execute(
        "UPDATE convites SET status = 'expired', updated_at = ? WHERE id = ?",
        [DateTime.now().toIso8601String(), invitationId],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao cancelar convite: ${e.toString()}');
    }
  }

  Invitation _fromMap(Map<String, dynamic> row) {
    return Invitation.fromMap(row);
  }
}
