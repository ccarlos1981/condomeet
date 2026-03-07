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
  final bool hasMore;
  final int offset;

  const InvitationLoaded({
    required this.invitations,
    this.hasMore = true,
    this.offset = 0,
  });

  @override
  List<Object?> get props => [invitations, hasMore, offset];
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
