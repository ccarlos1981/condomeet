import 'package:condomeet/core/services/powersync_service.dart';
import 'package:condomeet/shared/models/condominium.dart';

abstract class CondominiumRepository {
  Future<Condominium?> getCondominiumById(String id);
  Stream<Condominium?> watchCondominiumById(String id);
}

class CondominiumRepositoryImpl implements CondominiumRepository {
  final PowerSyncService _powerSync;

  CondominiumRepositoryImpl(this._powerSync);

  @override
  Future<Condominium?> getCondominiumById(String id) async {
    final result = await _powerSync.db.getOptional(
      'SELECT * FROM condominiums WHERE id = ? LIMIT 1',
      [id],
    );

    if (result == null) return null;

    return Condominium.fromJson(result);
  }

  @override
  Stream<Condominium?> watchCondominiumById(String id) {
    return _powerSync.db.watch(
      'SELECT * FROM condominiums WHERE id = ? LIMIT 1',
      parameters: [id],
    ).map((results) {
      if (results.isEmpty) return null;
      try {
        final rowMap = Map<String, dynamic>.from(results.first);
        return Condominium.fromJson(rowMap);
      } catch (e, stack) {
        print('CRITICAL: Error parsing Condominium Stream: \$e');
        print(stack);
        return null; // Return null instead of crashing the stream
      }
    });
  }
}
