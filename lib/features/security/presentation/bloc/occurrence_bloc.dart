import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/occurrence_repository.dart';
import '../../domain/models/occurrence.dart';
import 'occurrence_event.dart';
import 'occurrence_state.dart';

class OccurrenceBloc extends Bloc<OccurrenceEvent, OccurrenceState> {
  final OccurrenceRepository _occurrenceRepository;
  StreamSubscription? _occurrenceSubscription;

  OccurrenceBloc({required OccurrenceRepository occurrenceRepository})
      : _occurrenceRepository = occurrenceRepository,
        super(OccurrenceInitial()) {
    on<ReportOccurrenceRequested>(_onReportOccurrenceRequested);
    on<WatchResidentOccurrencesRequested>(_onWatchResidentOccurrencesRequested);
    on<WatchAllOccurrencesRequested>(_onWatchAllOccurrencesRequested);
    on<UpdateOccurrenceStatusRequested>(_onUpdateOccurrenceStatusRequested);
    on<_UpdateOccurrences>(_onUpdateOccurrences);
  }

  Future<void> _onReportOccurrenceRequested(ReportOccurrenceRequested event, Emitter<OccurrenceState> emit) async {
    emit(OccurrenceLoading());
    final result = await _occurrenceRepository.reportOccurrence(
      residentId: event.residentId,
      condominiumId: event.condominiumId,
      description: event.description,
      category: event.category,
      photoPaths: event.photoPaths,
    );

    result.fold(
      (error) => emit(OccurrenceError(error.message)),
      (_) => emit(OccurrenceSuccess()),
    );
  }

  Future<void> _onWatchResidentOccurrencesRequested(WatchResidentOccurrencesRequested event, Emitter<OccurrenceState> emit) async {
    await _occurrenceSubscription?.cancel();
    _occurrenceSubscription = _occurrenceRepository.watchResidentOccurrences(event.residentId).listen(
      (occurrences) => add(_UpdateOccurrences(occurrences)),
    );
  }

  Future<void> _onWatchAllOccurrencesRequested(WatchAllOccurrencesRequested event, Emitter<OccurrenceState> emit) async {
    await _occurrenceSubscription?.cancel();
    _occurrenceSubscription = _occurrenceRepository.watchAllOccurrences(event.condominiumId).listen(
      (occurrences) => add(_UpdateOccurrences(occurrences)),
    );
  }

  void _onUpdateOccurrences(_UpdateOccurrences event, Emitter<OccurrenceState> emit) {
    emit(OccurrenceLoaded(event.occurrences));
  }

  Future<void> _onUpdateOccurrenceStatusRequested(UpdateOccurrenceStatusRequested event, Emitter<OccurrenceState> emit) async {
    final result = await _occurrenceRepository.updateOccurrenceStatus(event.occurrenceId, event.status);
    if (result.isFailure) {
      emit(OccurrenceError(result.failureMessage));
    }
  }

  @override
  Future<void> close() {
    _occurrenceSubscription?.cancel();
    return super.close();
  }
}

class _UpdateOccurrences extends OccurrenceEvent {
  final List<Occurrence> occurrences;
  const _UpdateOccurrences(this.occurrences);
}
