import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/access/domain/models/invitation.dart';

abstract class InvitationRepository {
  /// Watches active invitations for a specific resident.
  Stream<List<Invitation>> watchInvitationsForResident(String residentId);

  /// Watches all active invitations for the condominium (Porter view).
  Stream<List<Invitation>> watchAllActiveInvitations(String condominiumId);

  /// Creates a new guest invitation.
  Future<Result<Invitation>> createInvitation({
    required String residentId,
    required String guestName,
    required DateTime validityDate,
    required String condominiumId,
    String? visitorType,
    String? visitorPhone,
    String? observation,
  });

  /// Fetches paginated invitations for a resident.
  Future<Result<List<Invitation>>> getResidentInvitationsPaginated({
    required String residentId,
    required int limit,
    required int offset,
  });

  /// Marks an invitation as used.
  Future<Result<void>> markAsUsed(String invitationId);

  /// Cancels an invitation.
  Future<Result<void>> cancelInvitation(String invitationId);
}
