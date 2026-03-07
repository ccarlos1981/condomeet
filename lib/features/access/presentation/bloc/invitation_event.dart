import 'package:equatable/equatable.dart';

abstract class InvitationEvent extends Equatable {
  const InvitationEvent();

  @override
  List<Object?> get props => [];
}

class WatchResidentInvitationsRequested extends InvitationEvent {
  final String residentId;
  const WatchResidentInvitationsRequested(this.residentId);

  @override
  List<Object?> get props => [residentId];
}

class WatchAllActiveInvitationsRequested extends InvitationEvent {
  final String condominiumId;
  const WatchAllActiveInvitationsRequested(this.condominiumId);

  @override
  List<Object?> get props => [condominiumId];
}

class CreateInvitationRequested extends InvitationEvent {
  final String residentId;
  final String guestName;
  final DateTime validityDate;
  final String condominiumId;

  const CreateInvitationRequested({
    required this.residentId,
    required this.guestName,
    required this.validityDate,
    required this.condominiumId,
  });

  @override
  List<Object?> get props => [residentId, guestName, validityDate, condominiumId];
}

class MarkInvitationAsUsedRequested extends InvitationEvent {
  final String invitationId;
  const MarkInvitationAsUsedRequested(this.invitationId);

  @override
  List<Object?> get props => [invitationId];
}

class CancelInvitationRequested extends InvitationEvent {
  final String invitationId;
  const CancelInvitationRequested(this.invitationId);

  @override
  List<Object?> get props => [invitationId];
}

class _UpdateInvitations extends InvitationEvent {
  final List<dynamic> invitations;
  const _UpdateInvitations(this.invitations);

  @override
  List<Object?> get props => [invitations];
}
