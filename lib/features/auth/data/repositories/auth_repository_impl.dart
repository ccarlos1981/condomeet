import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_resilience_service.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;
  final SupabaseResilienceService _resilienceService;

  AuthRepositoryImpl({
    required SupabaseClient supabase,
    SupabaseResilienceService? resilienceService,
  })  : _supabase = supabase,
        _resilienceService = resilienceService ?? SupabaseResilienceService();

  @override
  Session? get currentSession => _supabase.auth.currentSession;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    // Autenticação direta envolvida pelo ResilienceService:
    // NON_IDEMPOTENT_WRITE ➔ Timeout obrigatório (20s) | Retry = NÃO
    await _resilienceService.execute<void>(
      operationName: 'signInWithEmail',
      idempotency: OperationIdempotency.nonIdempotentWrite,
      timeout: const Duration(seconds: 20),
      action: () async {
        await _supabase.auth.signInWithPassword(email: email, password: password);
      },
    );
  }

  @override
  Future<String> signUpWithEmail(String email, String password) async {
    return _resilienceService.execute<String>(
      operationName: 'signUpWithEmail',
      idempotency: OperationIdempotency.nonIdempotentWrite,
      timeout: const Duration(seconds: 20),
      action: () async {
        final response = await _supabase.auth.signUp(email: email, password: password);
        if (response.user == null) {
          throw Exception('Não foi possível criar o usuário');
        }
        return response.user!.id;
      },
    );
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      print('SignOut: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    return _resilienceService.execute<Map<String, dynamic>?>(
      operationName: 'fetchProfile',
      idempotency: OperationIdempotency.readOnly,
      action: () async {
        final response = await _supabase
            .from('perfil')
            .select('''
              *,
              condominios(nome, tipo_estrutura),
              unidade_perfil(
                unidades(
                  id,
                  bloco_id,
                  apartamento_id,
                  bloqueada,
                  blocos(nome_ou_numero),
                  apartamentos(numero)
                )
              )
            ''')
            .eq('id', userId)
            .maybeSingle();
        return response;
      },
    );
  }

  @override
  Future<void> updateFcmToken(String userId, String token) async {
    await _resilienceService.execute<void>(
      operationName: 'updateFcmToken',
      idempotency: OperationIdempotency.idempotentWrite,
      action: () async {
        await _supabase.from('perfil').update({'fcm_token': token}).eq('id', userId);
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> searchCondominios(String query) async {
    return _resilienceService.execute<List<Map<String, dynamic>>>(
      operationName: 'searchCondominios',
      idempotency: OperationIdempotency.readOnly,
      action: () async {
        return await _supabase
            .from('condominios')
            .select('id, nome, cidade, estado, tipo_estrutura')
            .ilike('nome', '%$query%')
            .order('nome')
            .limit(10);
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getBlocos(String condominioId) async {
    return _resilienceService.execute<List<Map<String, dynamic>>>(
      operationName: 'getBlocos',
      idempotency: OperationIdempotency.readOnly,
      action: () async {
        try {
          final response = await _supabase
              .from('blocos')
              .select('id, nome_ou_numero')
              .eq('condominio_id', condominioId)
              .order('nome_ou_numero');

          final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response)
              .where((e) => e['nome_ou_numero'] != '0')
              .toList();
          print('📦 [AuthRepo] getBlocos: Encontrados ${data.length} blocos filtrados para o condomínio $condominioId');
          if (data.isEmpty) {
            print('⚠️ [AuthRepo] getBlocos: Lista vazia após filtro! Verifique se os blocos existem no Supabase.');
          }
          return data;
        } catch (e) {
          print('❌ getBlocos error: $e');
          rethrow;
        }
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getApartamentos(String condominioId, String blocoId) async {
    return _resilienceService.execute<List<Map<String, dynamic>>>(
      operationName: 'getApartamentos',
      idempotency: OperationIdempotency.readOnly,
      action: () async {
        try {
          final response = await _supabase
              .from('unidades')
              .select('apartamento_id, apartamentos(numero)')
              .eq('condominio_id', condominioId)
              .eq('bloco_id', blocoId)
              .order('apartamentos(numero)');

          print('📦 [AuthRepo] getApartamentos: Encontradas ${response.length} unidades vinculadas ao bloco $blocoId');
          if (response.isEmpty) {
            print('⚠️ [AuthRepo] getApartamentos: Nenhuma unidade encontrada!');
          }

          return response.map((e) {
            final aptoData = e['apartamentos'];
            String numero = '0';

            if (aptoData is List && aptoData.isNotEmpty) {
              numero = aptoData[0]['numero'].toString();
            } else if (aptoData is Map) {
              numero = aptoData['numero'].toString();
            }

            return {
              'id': e['apartamento_id'],
              'numero': numero,
            };
          }).where((e) => e['numero'] != '0').toList();
        } catch (e) {
          print('❌ getApartamentos error: $e');
          rethrow;
        }
      },
    );
  }

  @override
  Future<bool> isEmailAvailable(String email) async {
    return _resilienceService.execute<bool>(
      operationName: 'isEmailAvailable',
      idempotency: OperationIdempotency.readOnly,
      action: () async {
        try {
          final res = await _supabase.rpc(
            'check_email_exists',
            params: {'email_to_check': email.trim()},
          );
          return res == false;
        } catch (e) {
          print('Erro ao chamar RPC check_email_exists: $e');
          rethrow;
        }
      },
    );
  }

  @override
  Future<Map<String, dynamic>?> getUnidade(String condominioId, String blocoId, String apartamentoId) async {
    return _resilienceService.execute<Map<String, dynamic>?>(
      operationName: 'getUnidade',
      idempotency: OperationIdempotency.readOnly,
      action: () async {
        return await _supabase
            .from('unidades')
            .select()
            .eq('condominio_id', condominioId)
            .eq('bloco_id', blocoId)
            .eq('apartamento_id', apartamentoId)
            .maybeSingle();
      },
    );
  }

  @override
  Future<void> registerResident({
    required String userId,
    required String email,
    required String condominioId,
    required String unidadeId,
    required String nomeCompleto,
    required String whatsapp,
    required String tipoMorador,
    required String papelSistema,
    required bool consentimentoWhatsapp,
    String? blocoTxt,
    String? aptoTxt,
  }) async {
    await _resilienceService.execute<void>(
      operationName: 'registerResident',
      idempotency: OperationIdempotency.nonIdempotentWrite,
      action: () async {
        await _supabase.from('perfil').insert({
          'id': userId,
          'condominio_id': condominioId,
          'nome_completo': nomeCompleto,
          'email': email,
          'whatsapp': whatsapp,
          'whatsapp_msg_consent': consentimentoWhatsapp,
          'status_aprovacao': 'pendente',
          'tipo_morador': tipoMorador,
          'papel_sistema': papelSistema,
          'bloco_txt': blocoTxt,
          'apto_txt': aptoTxt,
        });

        if (unidadeId.isNotEmpty) {
          await _supabase.from('unidade_perfil').insert({
            'perfil_id': userId,
            'unidade_id': unidadeId,
          });
        }
      },
    );
  }

  @override
  Future<void> registerSindico({
    required String userId,
    required String email,
    required Map<String, dynamic> condominioData,
    required String nomeCompleto,
    required String whatsapp,
  }) async {
    await _resilienceService.execute<void>(
      operationName: 'registerSindico',
      idempotency: OperationIdempotency.nonIdempotentWrite,
      action: () async {
        final condominioResult = await _supabase.from('condominios').insert(condominioData).select().single();
        final condominioId = condominioResult['id'];

        final blocoResult = await _supabase.from('blocos').insert({
          'condominio_id': condominioId,
          'nome_ou_numero': '0',
        }).select().single();

        final aptoResult = await _supabase.from('apartamentos').insert({
          'condominio_id': condominioId,
          'numero': '0',
        }).select().single();

        final unidadeResult = await _supabase.from('unidades').insert({
          'condominio_id': condominioId,
          'bloco_id': blocoResult['id'],
          'apartamento_id': aptoResult['id'],
        }).select().single();

        await _supabase.from('perfil').insert({
          'id': userId,
          'condominio_id': condominioId,
          'nome_completo': nomeCompleto,
          'email': email,
          'whatsapp': whatsapp,
          'status_aprovacao': 'aprovado',
          'tipo_morador': 'Proprietário',
          'papel_sistema': 'Síndico',
        });

        await _supabase.from('unidade_perfil').insert({
          'perfil_id': userId,
          'unidade_id': unidadeResult['id'],
        });
      },
    );
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    await _resilienceService.execute<void>(
      operationName: 'resetPasswordForEmail',
      idempotency: OperationIdempotency.nonIdempotentWrite,
      action: () async {
        await _supabase.auth.resetPasswordForEmail(email);
      },
    );
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await _resilienceService.execute<void>(
      operationName: 'updatePassword',
      idempotency: OperationIdempotency.nonIdempotentWrite,
      action: () async {
        await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      },
    );
  }
}
