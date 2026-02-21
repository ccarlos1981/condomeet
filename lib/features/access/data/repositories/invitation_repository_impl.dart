import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/access/domain/models/invitation.dart';
import 'package:condomeet/features/access/domain/repositories/invitation_repository.dart';

class InvitationRepositoryImpl implements InvitationRepository {
  final List<Invitation> _mockInvitations = [];

  @override
  Future<Result<Invitation>> createInvitation({
    required String residentId,
    required String guestName,
    required DateTime validityDate,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final invitation = Invitation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      residentId: residentId,
      guestName: guestName,
      validityDate: validityDate,
      qrData: 'condomeet_inv_${DateTime.now().millisecondsSinceEpoch}',
    );
    _mockInvitations.add(invitation);
    return Success(invitation);
  }

  @override
  Future<Result<List<Invitation>>> getActiveInvitations() async {
    await Future.delayed(const Duration(milliseconds: 50));
    final active = _mockInvitations.where((i) => i.status == 'active').toList();
    return Success(active);
  }

  @override
  Future<Result<List<Invitation>>> getResidentInvitations(String residentId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final mine = _mockInvitations.where((i) => i.residentId == residentId).toList();
    return Success(mine);
  }

  @override
  Future<Result<void>> markAsUsed(String invitationId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final index = _mockInvitations.indexWhere((i) => i.id == invitationId);
    if (index != -1) {
      final old = _mockInvitations[index];
      _mockInvitations[index] = Invitation(
        id: old.id,
        residentId: old.residentId,
        guestName: old.guestName,
        validityDate: old.validityDate,
        qrData: old.qrData,
        status: 'used',
      );
    }
    return const Success(null);
  }
}
