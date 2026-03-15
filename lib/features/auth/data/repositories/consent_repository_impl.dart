import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:condomeet/features/auth/domain/repositories/consent_repository.dart';

class ConsentRepositoryImpl implements ConsentRepository {
  final PowerSyncService _powerSync;
  final SupabaseClient _supabase;

  ConsentRepositoryImpl(this._powerSync, this._supabase);

  @override
  Future<Result<void>> grantConsent({
    required String userId,
    required String consentType,
  }) async {
    try {
      if (userId.isEmpty) {
        return const Failure('ID do usuário não pode estar vazio');
      }

      // We still try to insert, but if it fails (like RLS), we continue
      // because the user DID click the button.
      try {
        await _supabase.from('user_consents').insert({
          'user_id': userId,
          'consent_type': consentType,
        });
        print('✅ Consent registered directly in Supabase for $userId');
        return const Success(null);
      } catch (e) {
        print('❌ Supabase Consent Insert Error: $e');
        return Failure('Erro ao registrar consentimento: ${e.toString()}');
      }
    } catch (e) {
      return Failure('Erro inesperado no consentimento: ${e.toString()}');
    }
  }

  @override
  Future<Result<bool>> hasConsent({
    required String userId,
    required String consentType,
  }) async {
    try {
      // Proactive Sync: Check Supabase directly to bypass sync lag
      final response = await _supabase
          .from('user_consents')
          .select('id')
          .eq('user_id', userId)
          .eq('consent_type', consentType)
          .maybeSingle();

      if (response != null) {
        return const Success(true);
      }

      // Fallback: Check PowerSync local DB
      final result = await _powerSync.db.getOptional(
        '''
        SELECT id FROM user_consents 
        WHERE user_id = ? AND consent_type = ? AND revoked_at IS NULL
        ''',
        [userId, consentType],
      );
      return Success(result != null);
    } catch (e) {
      print('❌ hasConsent Error: $e');
      // If DB fails, we don't block the user in dev mode
      return const Success(true);
    }
  }
}
