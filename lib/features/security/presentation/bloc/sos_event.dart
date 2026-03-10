import 'package:equatable/equatable.dart';

abstract class SOSEvent extends Equatable {
  const SOSEvent();

  @override
  List<Object?> get props => [];
}

class TriggerSOSRequested extends SOSEvent {
  final String residentId;
  final String condominiumId;
  final double latitude;
  final double longitude;

  const TriggerSOSRequested({
    required this.residentId,
    required this.condominiumId,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [residentId, condominiumId, latitude, longitude];
}

class WatchActiveSOSRequested extends SOSEvent {
  final String condominiumId;

  const WatchActiveSOSRequested(this.condominiumId);

  @override
  List<Object?> get props => [condominiumId];
}

class AcknowledgeSOSRequested extends SOSEvent {
  final String alertId;
  final String porterId;

  const AcknowledgeSOSRequested({
    required this.alertId,
    required this.porterId,
  });

  @override
  List<Object?> get props => [alertId, porterId];
}

