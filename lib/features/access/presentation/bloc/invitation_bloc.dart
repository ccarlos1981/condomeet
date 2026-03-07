import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/invitation.dart';
import '../../domain/repositories/invitation_repository.dart';
import 'invitation_event.dart';
import 'invitation_state.dart';

class InvitationBloc extends Bloc<InvitationEvent, InvitationState> {
  final InvitationRepository _invitationRepository;
  StreamSubscription? _invitationsSubscription;

  InvitationBloc({required InvitationRepository invitationRepository})
      : _invitationRepository = invitationRepository,
        super(InvitationInitial()) {
    on<WatchResidentInvitationsRequested>(_onWatchResidentInvitationsRequested);
    on<WatchAllActiveInvitationsRequested>(_onWatchAllActiveInvitationsRequested);
    on<CreateInvitationRequested>(_onCreateInvitationRequested);
    on<MarkInvitationAsUsedRequested>(_onMarkInvitationAsUsedRequested);
    on<CancelInvitationRequested>(_onCancelInvitationRequested);
    on<_UpdateInvitations>(_onUpdateInvitations);
  }

  Future<void> _onWatchResidentInvitationsRequested(
    WatchResidentInvitationsRequested event,
    Emitter<InvitationState> emit,
  ) async {
    emit(InvitationLoading());
    await _invitationsSubscription?.cancel();
    _invitationsSubscription = _invitationRepository
        .watchInvitationsForResident(event.residentId)
        .listen((invitations) => add(_UpdateInvitations(invitations)));
  }

  Future<void> _onWatchAllActiveInvitationsRequested(
    WatchAllActiveInvitationsRequested event,
    Emitter<InvitationState> emit,
  ) async {
    emit(InvitationLoading());
    await _invitationsSubscription?.cancel();
    _invitationsSubscription = _invitationRepository
        .watchAllActiveInvitations(event.condominiumId)
        .listen((invitations) => add(_UpdateInvitations(invitations)));
  }

  Future<void> _onCreateInvitationRequested(
    CreateInvitationRequested event,
    Emitter<InvitationState> emit,
  ) async {
    // We don't necessarily emit Loading here if we want a seamless creation, 
    // but for now it's fine.
    final result = await _invitationRepository.createInvitation(
      residentId: event.residentId,
      guestName: event.guestName,
      validityDate: event.validityDate,
      condominiumId: event.condominiumId,
    );

    if (result.isSuccess) {
      emit(InvitationCreated(result.successData));
    } else {
      emit(InvitationError(result.failureMessage));
    }
  }

  Future<void> _onMarkInvitationAsUsedRequested(
    MarkInvitationAsUsedRequested event,
    Emitter<InvitationState> emit,
  ) async {
    final result = await _invitationRepository.markAsUsed(event.invitationId);
    if (result.isFailure) {
      emit(InvitationError(result.failureMessage));
    }
  }

  Future<void> _onCancelInvitationRequested(
    CancelInvitationRequested event,
    Emitter<InvitationState> emit,
  ) async {
    final result = await _invitationRepository.cancelInvitation(event.invitationId);
    if (result.isFailure) {
      emit(InvitationError(result.failureMessage));
    }
  }

  void _onUpdateInvitations(
    _UpdateInvitations event,
    Emitter<InvitationState> emit,
  ) {
    emit(InvitationLoaded(event.invitations.cast<Invitation>()));
  }

  @override
  Future<void> close() {
    _invitationsSubscription?.cancel();
    return super.close();
  }
}

class _UpdateInvitations extends InvitationEvent {
  final List<Invitation> invitations;
  const _UpdateInvitations(this.invitations);
}
