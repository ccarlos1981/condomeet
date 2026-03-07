import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../portaria/domain/repositories/parcel_repository.dart';
import '../../../portaria/domain/entities/parcel.dart';
import 'parcel_event.dart';
import 'parcel_state.dart';

class ParcelBloc extends Bloc<ParcelEvent, ParcelState> {
  final ParcelRepository _parcelRepository;
  StreamSubscription? _parcelsSubscription;

  ParcelBloc(this._parcelRepository) : super(ParcelInitial()) {
    on<WatchPendingParcelsRequested>(_onWatchPendingParcelsRequested);
    on<WatchAllPendingParcelsRequested>(_onWatchAllPendingParcelsRequested);
    on<MarkParcelAsDeliveredRequested>(_onMarkParcelAsDeliveredRequested);
    on<FetchParcelHistoryRequested>(_onFetchParcelHistoryRequested);
    on<_UpdatePendingParcels>(_onUpdatePendingParcels);
  }

  Future<void> _onWatchPendingParcelsRequested(
    WatchPendingParcelsRequested event,
    Emitter<ParcelState> emit,
  ) async {
    emit(ParcelLoading());
    await _parcelsSubscription?.cancel();
    
    _parcelsSubscription = _parcelRepository
        .watchPendingParcelsForResident(event.residentId)
        .listen((parcels) {
      add(_UpdatePendingParcels(parcels));
    });
  }

  void _onUpdatePendingParcels(
    _UpdatePendingParcels event,
    Emitter<ParcelState> emit,
  ) {
    final currentState = state;
    if (currentState is ParcelLoaded) {
      emit(currentState.copyWith(pendingParcels: event.parcels));
    } else {
      emit(ParcelLoaded(pendingParcels: event.parcels));
    }
  }

  Future<void> _onWatchAllPendingParcelsRequested(
    WatchAllPendingParcelsRequested event,
    Emitter<ParcelState> emit,
  ) async {
    emit(ParcelLoading());
    await _parcelsSubscription?.cancel();
    
    _parcelsSubscription = _parcelRepository
        .watchAllPendingParcels(event.condominiumId)
        .listen((parcels) {
      add(_UpdatePendingParcels(parcels));
    });
  }

  Future<void> _onMarkParcelAsDeliveredRequested(
    MarkParcelAsDeliveredRequested event,
    Emitter<ParcelState> emit,
  ) async {
    final result = await _parcelRepository.markAsDelivered(
      event.parcelId,
      pickupProofUrl: event.pickupProofUrl,
    );
    if (result.isFailure) {
      emit(ParcelError(result.failureMessage));
    }
  }

  Future<void> _onFetchParcelHistoryRequested(
    FetchParcelHistoryRequested event,
    Emitter<ParcelState> emit,
  ) async {
    final result = await _parcelRepository.getParcelHistory(
      residentId: event.residentId,
      condominiumId: event.condominiumId,
    );
    
    result.fold(
      (error) => emit(ParcelError(error.message)),
      (history) {
        final currentState = state;
        if (currentState is ParcelLoaded) {
          emit(currentState.copyWith(historyParcels: history));
        } else {
          emit(ParcelLoaded(historyParcels: history));
        }
      },
    );
  }

  @override
  Future<void> close() {
    _parcelsSubscription?.cancel();
    return super.close();
  }
}

/// Internal event to update the state from the stream
class _UpdatePendingParcels extends ParcelEvent {
  final List<Parcel> parcels;
  const _UpdatePendingParcels(this.parcels);

  @override
  List<Object?> get props => [parcels];
}
