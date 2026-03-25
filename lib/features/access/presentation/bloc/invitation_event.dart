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

/// Portaria: watch all invitations with optional filters
class WatchCondominiumInvitationsRequested extends InvitationEvent {
  final String condominiumId;
  final bool? liberado;
  final String? codeFilter;
  final String? blocoFilter;
  final String? aptoFilter;
  final String? dateFilter;
  final int? limit;

  const WatchCondominiumInvitationsRequested({
    required this.condominiumId,
    this.liberado,
    this.codeFilter,
    this.blocoFilter,
    this.aptoFilter,
    this.dateFilter,
    this.limit,
  });

  @override
  List<Object?> get props => [condominiumId, liberado, codeFilter, blocoFilter, aptoFilter, dateFilter, limit];
}

/// Portaria: approve visitor entry
class ApproveVisitorEntryRequested extends InvitationEvent {
  final String invitationId;
  final String porterId;
  const ApproveVisitorEntryRequested({required this.invitationId, required this.porterId});

  @override
  List<Object?> get props => [invitationId, porterId];
}

class CreateInvitationRequested extends InvitationEvent {
  final String residentId;
  final String guestName;
  final DateTime validityDate;
  final String condominiumId;
  final String? visitorType;
  final String? visitorPhone;
  final String? observation;
  final String? documento;
  final String? placa;
  final String? crachaReferencia;

  const CreateInvitationRequested({
    required this.residentId,
    required this.guestName,
    required this.validityDate,
    required this.condominiumId,
    this.visitorType,
    this.visitorPhone,
    this.observation,
    this.documento,
    this.placa,
    this.crachaReferencia,
  });

  @override
  List<Object?> get props => [
        residentId,
        guestName,
        validityDate,
        condominiumId,
        visitorType,
        visitorPhone,
        observation,
        documento,
        placa,
        crachaReferencia,
      ];
}

class LoadResidentInvitationsPaginated extends InvitationEvent {
  final String residentId;
  final int limit;
  final int offset;
  final bool isRefresh;

  const LoadResidentInvitationsPaginated({
    required this.residentId,
    this.limit = 5,
    this.offset = 0,
    this.isRefresh = false,
  });

  @override
  List<Object?> get props => [residentId, limit, offset, isRefresh];
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

// ignore: unused_element
class _UpdateInvitations extends InvitationEvent {
  final List<dynamic> invitations;
  const _UpdateInvitations(this.invitations);

  @override
  List<Object?> get props => [invitations];
}
