enum BookingStatus { confirmed, cancelled }

class CommonArea {
  final String id;
  final String condominiumId;
  final String name;
  final String description;
  final String iconPath;
  final int capacity;
  final String rules;

  CommonArea({
    required this.id,
    required this.condominiumId,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.capacity,
    required this.rules,
  });

  factory CommonArea.fromMap(Map<String, dynamic> map) {
    final tipoAgenda = map['tipo_agenda'] as String? ?? map['name'] as String? ?? '';
    return CommonArea(
      id: map['id'],
      condominiumId: map['condominio_id'] ?? map['condominium_id'],
      name: tipoAgenda,
      description: map['instrucao_uso'] as String? ?? map['description'] as String? ?? '',
      iconPath: _iconForTipo(tipoAgenda),
      capacity: (map['capacidade'] as int?) ?? (map['capacity'] as int?) ?? 0,
      rules: map['instrucao_uso'] as String? ?? map['rules'] as String? ?? '',
    );
  }

  static String _iconForTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'salão de festa': return 'party_room';
      case 'churrasqueira': return 'grill';
      case 'sauna': return 'sauna';
      case 'quadra de tênis': case 'campo de futebol': return 'sports';
      case 'piscina': return 'pool';
      case 'academia': return 'gym';
      default: return 'location';
    }
  }
}

class AreaBooking {
  final String id;
  final String condominiumId;
  final String areaId;
  final String residentId;
  final DateTime bookingDate;
  final BookingStatus status;

  AreaBooking({
    required this.id,
    required this.condominiumId,
    required this.areaId,
    required this.residentId,
    required this.bookingDate,
    required this.status,
  });

  factory AreaBooking.fromMap(Map<String, dynamic> map) {
    return AreaBooking(
      id: map['id'],
      condominiumId: map['condominio_id'] ?? map['condominium_id'],
      areaId: map['area_id'],
      residentId: map['resident_id'],
      bookingDate: DateTime.parse(map['booking_date']),
      status: map['status'] == 'cancelled' ? BookingStatus.cancelled : BookingStatus.confirmed,
    );
  }
}

class AvailabilitySlot {
  final DateTime date;
  final bool isAvailable;
  final String? bookedByUnit;

  AvailabilitySlot({
    required this.date,
    this.isAvailable = true,
    this.bookedByUnit,
  });
}
