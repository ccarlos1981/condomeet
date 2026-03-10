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
    on<LoadResidentInvitationsPaginated>(_onLoadResidentInvitationsPaginated);
    on<WatchResidentInvitationsRequested>(_onWatchResidentInvitationsRequested);
    on<WatchAllActiveInvitationsRequested>(_onWatchAllActiveInvitationsRequested);
    on<WatchCondominiumInvitationsRequested>(_onWatchCondominiumInvitationsRequested);
    on<CreateInvitationRequested>(_onCreateInvitationRequested);
    on<ApproveVisitorEntryRequested>(_onApproveVisitorEntryRequested);
    on<MarkInvitationAsUsedRequested>(_onMarkInvitationAsUsedRequested);
    on<CancelInvitationRequested>(_onCancelInvitationRequested);
    on<_UpdateInvitations>(_onUpdateInvitations);
  }

  Future<void> _onLoadResidentInvitationsPaginated(
    LoadResidentInvitationsPaginated event,
    Emitter<InvitationState> emit,
  ) async {
    if (event.isRefresh) {
      emit(InvitationLoading());
    }

    final result = await _invitationRepository.getResidentInvitationsPaginated(
      residentId: event.residentId,
      limit: event.limit,
      offset: event.offset,
    );

    if (result.isSuccess) {
      final newInvitations = result.successData;
      final currentInvitations = state is InvitationLoaded && !event.isRefresh
          ? (state as InvitationLoaded).invitations
          : <Invitation>[];
      
      emit(InvitationLoaded(
        invitations: [...currentInvitations, ...newInvitations],
        hasMore: newInvitations.length == event.limit,
        offset: event.offset + newInvitations.length,
      ));
    } else {
      emit(InvitationError(result.failureMessage));
    }
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

  Future<void> _onWatchCondominiumInvitationsRequested(
    WatchCondominiumInvitationsRequested event,
    Emitter<InvitationState> emit,
  ) async {
    emit(InvitationLoading());
    await _invitationsSubscription?.cancel();
    _invitationsSubscription = _invitationRepository
        .watchCondominiumInvitations(
          condominiumId: event.condominiumId,
          liberado: event.liberado,
          codeFilter: event.codeFilter,
          blocoFilter: event.blocoFilter,
          aptoFilter: event.aptoFilter,
          dateFilter: event.dateFilter,
        )
        .listen((invitations) => add(_UpdateInvitations(invitations)));
  }

  Future<void> _onApproveVisitorEntryRequested(
    ApproveVisitorEntryRequested event,
    Emitter<InvitationState> emit,
  ) async {
    final result = await _invitationRepository.approveVisitorEntry(
      invitationId: event.invitationId,
      porterId: event.porterId,
    );
    if (result.isSuccess) {
      emit(VisitorEntryApproved(event.invitationId));
    } else {
      emit(InvitationError(result.failureMessage));
    }
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
      visitorType: event.visitorType,
      visitorPhone: event.visitorPhone,
      observation: event.observation,
    );

    if (result.isSuccess) {
      emit(InvitationCreated(result.successData));
      // Re-trigger load to update list if needed, or simply let the watch handle it.
      // Since we have a watch, it might update automatically.
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
    emit(InvitationLoaded(
      invitations: event.invitations.cast<Invitation>(),
      hasMore: false, // Watch is usually for active ones, not full history
      offset: 0,
    ));
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
