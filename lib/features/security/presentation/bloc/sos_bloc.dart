import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/sos_repository.dart';
import 'sos_event.dart';
import 'sos_state.dart';

class SOSBloc extends Bloc<SOSEvent, SOSState> {
  final SOSRepository _sosRepository;
  StreamSubscription? _sosSubscription;

  SOSBloc({required SOSRepository sosRepository})
      : _sosRepository = sosRepository,
        super(SOSInitial()) {
    on<TriggerSOSRequested>(_onTriggerSOSRequested);
    on<WatchActiveSOSRequested>(_onWatchActiveSOSRequested);
    on<AcknowledgeSOSRequested>(_onAcknowledgeSOSRequested);
    on<_UpdateSOSAlerts>(_onUpdateSOSAlerts);
  }

  Future<void> _onTriggerSOSRequested(TriggerSOSRequested event, Emitter<SOSState> emit) async {
    emit(SOSLoading());
    final result = await _sosRepository.triggerSOS(
      residentId: event.residentId,
      condominiumId: event.condominiumId,
      latitude: event.latitude,
      longitude: event.longitude,
    );
    
    result.fold(
      (error) => emit(SOSError(error.message)),
      (_) => emit(SOSSuccess()),
    );
  }

  Future<void> _onWatchActiveSOSRequested(WatchActiveSOSRequested event, Emitter<SOSState> emit) async {
    await _sosSubscription?.cancel();
    _sosSubscription = _sosRepository.watchActiveAlerts(event.condominiumId).listen(
      (alerts) => add(_UpdateSOSAlerts(alerts)),
    );
  }

  void _onUpdateSOSAlerts(_UpdateSOSAlerts event, Emitter<SOSState> emit) {
    emit(SOSActive(event.alerts));
  }

  Future<void> _onAcknowledgeSOSRequested(AcknowledgeSOSRequested event, Emitter<SOSState> emit) async {
    final result = await _sosRepository.acknowledgeAlert(event.alertId, event.porterId);
    if (result.isFailure) {
      emit(SOSError(result.failureMessage));
    }
  }

  @override
  Future<void> close() {
    _sosSubscription?.cancel();
    return super.close();
  }
}

class _UpdateSOSAlerts extends SOSEvent {
  final List<SOSAlert> alerts; 
  const _UpdateSOSAlerts(this.alerts);
}
