import 'package:equatable/equatable.dart';
import '../../../portaria/domain/entities/parcel.dart';

abstract class ParcelEvent extends Equatable {
  const ParcelEvent();

  @override
  List<Object?> get props => [];
}

class WatchPendingParcelsRequested extends ParcelEvent {
  final String residentId;
  const WatchPendingParcelsRequested(this.residentId);

  @override
  List<Object?> get props => [residentId];
}

class WatchAllPendingParcelsRequested extends ParcelEvent {
  final String condominiumId;
  const WatchAllPendingParcelsRequested(this.condominiumId);

  @override
  List<Object?> get props => [condominiumId];
}

class MarkParcelAsDeliveredRequested extends ParcelEvent {
  final String parcelId;
  final String? pickupProofUrl;
  const MarkParcelAsDeliveredRequested(this.parcelId, {this.pickupProofUrl});

  @override
  List<Object?> get props => [parcelId, pickupProofUrl];
}

class FetchParcelHistoryRequested extends ParcelEvent {
  final String? residentId;
  final String condominiumId;
  const FetchParcelHistoryRequested({this.residentId, required this.condominiumId});

  @override
  List<Object?> get props => [residentId, condominiumId];
}
