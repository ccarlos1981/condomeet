import 'package:condomeet/core/services/powersync_service.dart';
import 'package:condomeet/shared/models/condominium.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CondominiumRepository {
  Future<Condominium?> getCondominiumById(String id);
  Stream<Condominium?> watchCondominiumById(String id);
}

class CondominiumRepositoryImpl implements CondominiumRepository {
  final PowerSyncService _powerSync;
  final SupabaseClient _supabase;

  CondominiumRepositoryImpl(this._powerSync, this._supabase);

  /// Fetch directly from Supabase so features_config is always current.
  /// PowerSync cloud does not sync features_config, so we bypass it here.
  @override
  Future<Condominium?> getCondominiumById(String id) async {
    try {
      final row = await _supabase
          .from('condominios')
          .select('id, nome, apelido, tipo_estrutura, features_config, created_at, updated_at')
          .eq('id', id)
          .maybeSingle();
      if (row != null) {

        return Condominium.fromJson(row);
      }
    } catch (e) {
      print('⚠️ CondominiumRepository: Supabase fetch error: $e');
    }

    // Fallback: PowerSync local cache (features_config may be null here)
    final result = await _powerSync.db.getOptional(
      'SELECT * FROM condominios WHERE id = ? LIMIT 1',
      [id],
    );
    if (result == null) return null;
    print('⚠️ CondominiumRepository: falling back to PowerSync local cache');
    return Condominium.fromJson(result);
  }

  /// Streams the condominium, fetching immediately then refreshing every 30s.
  /// Uses a simple polling approach to avoid realtime subscription issues.
  @override
  Stream<Condominium?> watchCondominiumById(String id) async* {
    // Immediately yield current value
    yield await getCondominiumById(id);

    // Then refresh every 60 seconds so config changes propagate
    await for (final _ in Stream.periodic(const Duration(seconds: 60))) {
      yield await getCondominiumById(id);
    }
  }
}
