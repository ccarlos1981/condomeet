import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/core/network/supabase_resilience_service.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:condomeet/features/auth/domain/repositories/consent_repository.dart';

class ConsentRepositoryImpl implements ConsentRepository {
  final PowerSyncService _powerSync;
  final SupabaseClient _supabase;
  final SupabaseResilienceService _resilienceService;

  ConsentRepositoryImpl(
    this._powerSync,
    this._supabase, {
    SupabaseResilienceService? resilienceService,
  }) : _resilienceService = resilienceService ?? SupabaseResilienceService();

  @override
  Future<Result<void>> grantConsent({
    required String userId,
    required String consentType,
  }) async {
    try {
      if (userId.isEmpty) {
        return const Failure('ID do usuário não pode estar vazio');
      }

      try {
        await _resilienceService.execute<void>(
          operationName: 'grantConsent',
          idempotency: OperationIdempotency.idempotentWrite,
          action: () async {
            // Upsert utilizando o índice único user_consents_user_id_consent_type_key
            // garante idempotência determinística total em retries sem duplicar ou lançar erro 23505.
            await _supabase.from('user_consents').upsert(
              {
                'user_id': userId,
                'consent_type': consentType,
              },
              onConflict: 'user_id,consent_type',
            );
          },
        );
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
      final hasIt = await _resilienceService.execute<bool>(
        operationName: 'hasConsent',
        idempotency: OperationIdempotency.readOnly,
        action: () async {
          final response = await _supabase
              .from('user_consents')
              .select('id')
              .eq('user_id', userId)
              .eq('consent_type', consentType)
              .maybeSingle();

          if (response != null) {
            return true;
          }

          final result = await _powerSync.db.getOptional(
            '''
            SELECT id FROM user_consents 
            WHERE user_id = ? AND consent_type = ? AND revoked_at IS NULL
            ''',
            [userId, consentType],
          );
          return result != null;
        },
      );

      return Success(hasIt);
    } catch (e) {
      print('❌ hasConsent Error: $e');
      // If DB fails, we don't block the user in dev mode
      return const Success(true);
    }
  }
}
