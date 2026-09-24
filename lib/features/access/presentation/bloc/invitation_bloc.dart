import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/services/live_activity_service.dart';
import '../../domain/models/invitation.dart';
import '../../domain/repositories/invitation_repository.dart';
import 'invitation_event.dart';
import 'invitation_state.dart';

class InvitationBloc extends Bloc<InvitationEvent, InvitationState> {
  final InvitationRepository _invitationRepository;
  StreamSubscription? _invitationsSubscription;
  final List<Invitation> _cachedResidentInvitations = [];

  List<Invitation> get cachedResidentInvitations => List.unmodifiable(_cachedResidentInvitations);

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
      if (event.isRefresh) {
        _cachedResidentInvitations.clear();
      }
      for (final inv in newInvitations) {
        final existingIdx = _cachedResidentInvitations.indexWhere((i) => i.id == inv.id);
        if (existingIdx >= 0) {
          _cachedResidentInvitations[existingIdx] = inv;
        } else {
          _cachedResidentInvitations.add(inv);
        }
      }

      // Sincronizar Live Activity com as autorizações abertas consolidadas
      final openList = _cachedResidentInvitations.where(LiveActivityService.isInvitationOpen).toList();
      unawaited(LiveActivityService.syncActiveInvitationsState(
        openInvitations: openList,
        moradorNome: LiveActivityService.cachedMoradorNome ?? 'Morador',
        condominioNome: LiveActivityService.cachedCondominioNome ?? 'Condomínio',
      ));

      emit(InvitationLoaded(
        invitations: List.from(_cachedResidentInvitations),
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
          limit: event.limit,
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
    final result = await _invitationRepository.createInvitation(
      residentId: event.residentId,
      guestName: event.guestName,
      validityDate: event.validityDate,
      condominiumId: event.condominiumId,
      visitorType: event.visitorType,
      visitorPhone: event.visitorPhone,
      observation: event.observation,
      documento: event.documento,
      placa: event.placa,
      crachaReferencia: event.crachaReferencia,
      validUntil: event.validUntil,
    );

    if (result.isSuccess) {
      final created = result.successData;
      // Inserir convite criado no início da coleção consolidada
      _cachedResidentInvitations.removeWhere((i) => i.id == created.id);
      _cachedResidentInvitations.insert(0, created);

      // Recalcular as autorizações abertas usando a fonte de verdade única
      final openList = _cachedResidentInvitations.where(LiveActivityService.isInvitationOpen).toList();
      unawaited(LiveActivityService.syncActiveInvitationsState(
        openInvitations: openList,
        moradorNome: LiveActivityService.cachedMoradorNome ?? 'Morador',
        condominioNome: LiveActivityService.cachedCondominioNome ?? 'Condomínio',
      ));

      emit(InvitationCreated(created));
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
    } else {
      // Atualizar status para 'cancelled' na coleção consolidada
      final idx = _cachedResidentInvitations.indexWhere((i) => i.id == event.invitationId);
      if (idx >= 0) {
        final old = _cachedResidentInvitations[idx];
        _cachedResidentInvitations[idx] = Invitation(
          id: old.id,
          residentId: old.residentId,
          condominiumId: old.condominiumId,
          guestName: old.guestName,
          validityDate: old.validityDate,
          qrData: old.qrData,
          status: 'cancelled',
          visitanteCompareceu: old.visitanteCompareceu,
          liberadoPor: old.liberadoPor,
          liberadoEm: old.liberadoEm,
          residentName: old.residentName,
          blocoTxt: old.blocoTxt,
          aptoTxt: old.aptoTxt,
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
          visitorType: old.visitorType,
          visitorPhone: old.visitorPhone,
          observation: old.observation,
          validUntil: old.validUntil,
          parentId: old.parentId,
        );
      }

      final remainingOpen = _cachedResidentInvitations
          .where(LiveActivityService.isInvitationOpen)
          .toList();

      unawaited(LiveActivityService.syncActiveInvitationsState(
        openInvitations: remainingOpen,
        moradorNome: LiveActivityService.cachedMoradorNome ?? 'Morador',
        condominioNome: LiveActivityService.cachedCondominioNome ?? 'Condomínio',
      ));
    }
  }

  void _onUpdateInvitations(
    _UpdateInvitations event,
    Emitter<InvitationState> emit,
  ) {
    _cachedResidentInvitations.clear();
    _cachedResidentInvitations.addAll(event.invitations);

    final openList = _cachedResidentInvitations.where(LiveActivityService.isInvitationOpen).toList();
    unawaited(LiveActivityService.syncActiveInvitationsState(
      openInvitations: openList,
      moradorNome: LiveActivityService.cachedMoradorNome ?? 'Morador',
      condominioNome: LiveActivityService.cachedCondominioNome ?? 'Condomínio',
    ));

    emit(InvitationLoaded(
      invitations: List.from(_cachedResidentInvitations),
      hasMore: false,
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
