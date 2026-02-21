import 'dart:async';
import 'package:condomeet/core/errors/result.dart';
import '../../domain/repositories/sos_repository.dart';

class SOSRepositoryImpl implements SOSRepository {
  final _alertsController = StreamController<List<SOSAlert>>.broadcast();
  final List<SOSAlert> _activeAlerts = [];

  @override
  Future<Result<void>> triggerSOS({
    required String residentId,
    required double latitude,
    required double longitude,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    final newAlert = SOSAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      residentId: residentId,
      residentName: residentId == 'res123' ? 'Cristiano Carlos' : 'Novo Morador',
      unit: '501-B',
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
    );

    _activeAlerts.add(newAlert);
    _alertsController.add(List.from(_activeAlerts));
    
    return const Success(null);
  }

  @override
  Stream<List<SOSAlert>> watchActiveAlerts() {
    return _alertsController.stream;
  }

  @override
  Future<Result<void>> acknowledgeAlert(String alertId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _activeAlerts.removeWhere((a) => a.id == alertId);
    _alertsController.add(List.from(_activeAlerts));
    return const Success(null);
  }

  void dispose() {
    _alertsController.close();
  }
}

final sosRepository = SOSRepositoryImpl();
