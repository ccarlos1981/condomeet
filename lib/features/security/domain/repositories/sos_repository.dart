import 'package:condomeet/core/errors/result.dart';

abstract class SOSRepository {
  /// Triggers a critical SOS alert for the current resident.
  Future<Result<void>> triggerSOS({
    required String residentId,
    required double latitude,
    required double longitude,
  });

  /// Listens to active SOS alerts (Porter view).
  Stream<List<SOSAlert>> watchActiveAlerts();

  /// Acknowledges an alert by the porter.
  Future<Result<void>> acknowledgeAlert(String alertId);
}

class SOSAlert {
  final String id;
  final String residentId;
  final String residentName;
  final String unit;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isAcknowledged;

  SOSAlert({
    required this.id,
    required this.residentId,
    required this.residentName,
    required this.unit,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.isAcknowledged = false,
  });
}
