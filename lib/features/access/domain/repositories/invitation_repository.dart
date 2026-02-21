import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/access/domain/models/invitation.dart';

abstract class InvitationRepository {
  /// Creates a new guest invitation.
  Future<Result<Invitation>> createInvitation({
    required String residentId,
    required String guestName,
    required DateTime validityDate,
  });

  /// Fetches active invitations for a condominium (porter view).
  Future<Result<List<Invitation>>> getActiveInvitations();

  /// Fetches invitations created by a specific resident.
  Future<Result<List<Invitation>>> getResidentInvitations(String residentId);

  /// Marks an invitation as used.
  Future<Result<void>> markAsUsed(String invitationId);
}
