import 'package:equatable/equatable.dart';
import '../../domain/models/invitation.dart';

abstract class InvitationState extends Equatable {
  const InvitationState();

  @override
  List<Object?> get props => [];
}

class InvitationInitial extends InvitationState {}

class InvitationLoading extends InvitationState {}

class InvitationLoaded extends InvitationState {
  final List<Invitation> invitations;
  const InvitationLoaded(this.invitations);

  @override
  List<Object?> get props => [invitations];
}

class InvitationError extends InvitationState {
  final String message;
  const InvitationError(this.message);

  @override
  List<Object?> get props => [message];
}

class InvitationCreated extends InvitationState {
  final Invitation invitation;
  const InvitationCreated(this.invitation);

  @override
  List<Object?> get props => [invitation];
}
