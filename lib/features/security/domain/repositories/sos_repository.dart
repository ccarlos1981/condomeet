import 'package:condomeet/core/errors/result.dart';

abstract class SOSRepository {
  /// Triggers a critical SOS alert for the current resident.
  Future<Result<void>> triggerSOS({
    required String residentId,
    required String condominiumId,
    required double latitude,
    required double longitude,
  });

  /// Listens to active SOS alerts (Porter view).
  Stream<List<SOSAlert>> watchActiveAlerts(String condominiumId);

  /// Acknowledges an alert by the porter.
  Future<Result<void>> acknowledgeAlert(String alertId, String porterId);
}

enum SOSStatus { active, acknowledged, resolved }

class SOSAlert {
  final String id;
  final String residentId;
  final String residentName;
  final String? unit;
  final String condominiumId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final SOSStatus status;
  final String? acknowledgedBy;

  SOSAlert({
    required this.id,
    required this.residentId,
    required this.residentName,
    this.unit,
    required this.condominiumId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.status = SOSStatus.active,
    this.acknowledgedBy,
  });

  factory SOSAlert.fromMap(Map<String, dynamic> map) {
    return SOSAlert(
      id: map['id'],
      residentId: map['resident_id'],
      residentName: map['full_name'] ?? 'Morador',
      unit: map['unit_number'] != null ? '${map['unit_number']}-${map['block']}' : null,
      condominiumId: map['condominium_id'],
      latitude: map['latitude'] is String ? double.parse(map['latitude']) : map['latitude'],
      longitude: map['longitude'] is String ? double.parse(map['longitude']) : map['longitude'],
      timestamp: DateTime.parse(map['created_at']),
      status: SOSStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'active'),
        orElse: () => SOSStatus.active,
      ),
      acknowledgedBy: map['acknowledged_by'],
    );
  }
}
