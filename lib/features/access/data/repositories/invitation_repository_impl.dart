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
        status: 'active',
        createdAt: now,
        updatedAt: now,
      );

      await _powerSync.db.execute(
        '''INSERT INTO convites (id, resident_id, condominio_id, guest_name, validity_date, qr_data, status, created_at, updated_at) 
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [id, residentId, condominiumId, guestName, validityDate.toIso8601String(), qrData, 'active', now.toIso8601String(), now.toIso8601String()],
      );

      return Success(invitation);
    } catch (e) {
      return Failure('Erro ao criar convite: ${e.toString()}');
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

  Invitation _fromMap(Map<String, dynamic> map) {
    return Invitation(
      id: map['id'] as String,
      residentId: map['resident_id'] as String,
      condominiumId: (map['condominio_id'] ?? map['condominium_id']) as String,
      guestName: map['guest_name'] as String,
      validityDate: DateTime.parse(map['validity_date'] as String),
      qrData: map['qr_data'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
