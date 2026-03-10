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

  /// Saves or updates the user's trusted emergency contacts.
  Future<Result<void>> saveSosContatos({
    required String userId,
    required SosContatos contatos,
  });

  /// Retrieves the user's trusted emergency contacts (null if none saved yet).
  Future<SosContatos?> getSosContatos(String userId);
}

// ── SOSAlert model ──────────────────────────────────────────────────────────

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
      latitude: map['latitude'] is String ? double.parse(map['latitude']) : (map['latitude'] ?? 0.0),
      longitude: map['longitude'] is String ? double.parse(map['longitude']) : (map['longitude'] ?? 0.0),
      timestamp: DateTime.parse(map['created_at']),
      status: SOSStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'active'),
        orElse: () => SOSStatus.active,
      ),
      acknowledgedBy: map['acknowledged_by'],
    );
  }
}

// ── SosContatos model ───────────────────────────────────────────────────────

class SosContatos {
  final String? id;
  final String userId;
  final String? contato1Nome;
  final String? contato1Whatsapp;
  final String? contato2Nome;
  final String? contato2Whatsapp;
  final bool aceiteResponsabilidade;

  SosContatos({
    this.id,
    required this.userId,
    this.contato1Nome,
    this.contato1Whatsapp,
    this.contato2Nome,
    this.contato2Whatsapp,
    this.aceiteResponsabilidade = false,
  });

  factory SosContatos.fromMap(Map<String, dynamic> map) {
    return SosContatos(
      id: map['id'],
      userId: map['user_id'],
      contato1Nome: map['contato1_nome'],
      contato1Whatsapp: map['contato1_whatsapp'],
      contato2Nome: map['contato2_nome'],
      contato2Whatsapp: map['contato2_whatsapp'],
      aceiteResponsabilidade: map['aceite_responsabilidade'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'contato1_nome': contato1Nome,
      'contato1_whatsapp': contato1Whatsapp,
      'contato2_nome': contato2Nome,
      'contato2_whatsapp': contato2Whatsapp,
      'aceite_responsabilidade': aceiteResponsabilidade,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
