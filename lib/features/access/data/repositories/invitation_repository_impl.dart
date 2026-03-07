import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:uuid/uuid.dart';
import 'package:condomeet/features/access/domain/models/invitation.dart';
import 'package:condomeet/features/access/domain/repositories/invitation_repository.dart';
class InvitationRepositoryImpl implements InvitationRepository {
  final PowerSyncService _powerSync;

  InvitationRepositoryImpl(this._powerSync);

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
            status, created_at, updated_at
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
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
