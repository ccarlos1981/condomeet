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
    await _parcelsSubscription?.cancel();
    _parcelsSubscription = null;

    final residentId = event.residentId.trim();
    if (residentId.isEmpty) {
      // Fail-closed: se residentId estiver vazio, emitir lista pessoal vazia e abortar
      emit(const ParcelLoaded(
        pendingParcels: [],
        historyParcels: [],
        isPersonal: true,
      ));
      return;
    }

    // No início de uma nova consulta pessoal: emitir estado de Loading/limpeza
    // para impedir que um ParcelLoaded anterior contendo encomendas condominiais
    // seja reutilizado na tela pessoal.
    emit(ParcelLoading());

    _parcelsSubscription = _parcelRepository
        .watchPendingParcelsForUnit(residentId)
        .listen((parcels) {
      add(_UpdatePendingParcels(parcels, isPersonal: true));
    });
  }

  void _onUpdatePendingParcels(
    _UpdatePendingParcels event,
    Emitter<ParcelState> emit,
  ) {
    final currentState = state;
    if (currentState is ParcelLoaded && currentState.isPersonal == event.isPersonal) {
      emit(currentState.copyWith(
        pendingParcels: event.parcels,
        isPersonal: event.isPersonal,
      ));
    } else {
      emit(ParcelLoaded(
        pendingParcels: event.parcels,
        isPersonal: event.isPersonal,
      ));
    }
  }

  Future<void> _onWatchAllPendingParcelsRequested(
    WatchAllPendingParcelsRequested event,
    Emitter<ParcelState> emit,
  ) async {
    await _parcelsSubscription?.cancel();
    _parcelsSubscription = null;

    final condoId = event.condominiumId.trim();
    if (condoId.isEmpty) {
      emit(const ParcelLoaded(
        pendingParcels: [],
        isPersonal: false,
      ));
      return;
    }

    emit(ParcelLoading());

    _parcelsSubscription = _parcelRepository
        .watchAllPendingParcels(condoId)
        .listen((parcels) {
      add(_UpdatePendingParcels(parcels, isPersonal: false));
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
    final residentId = event.residentId?.trim();
    if (residentId == null || residentId.isEmpty) {
      // Se residentId estiver vazio/null: emitir histórico vazio e abortar.
      // NUNCA manter silenciosamente o estado anterior ou buscar do condomínio.
      final currentState = state;
      if (currentState is ParcelLoaded) {
        emit(currentState.copyWith(historyParcels: []));
      } else {
        emit(const ParcelLoaded(historyParcels: [], isPersonal: true));
      }
      return;
    }

    final result = await _parcelRepository.getParcelHistory(
      residentId: residentId,
      condominiumId: event.condominiumId,
    );

    result.fold(
      (error) => emit(ParcelError(error.message)),
      (history) {
        final currentState = state;
        if (currentState is ParcelLoaded) {
          emit(currentState.copyWith(historyParcels: history));
        } else {
          emit(ParcelLoaded(historyParcels: history, isPersonal: true));
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
  final bool isPersonal;
  const _UpdatePendingParcels(this.parcels, {this.isPersonal = true});

  @override
  List<Object?> get props => [parcels, isPersonal];
}
