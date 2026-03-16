import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;

  AuthRepositoryImpl({required SupabaseClient supabase}) : _supabase = supabase;

  @override
  Session? get currentSession => _supabase.auth.currentSession;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<String> signUpWithEmail(String email, String password) async {
    final response = await _supabase.auth.signUp(email: email, password: password);
    if (response.user == null) {
      throw Exception('Não foi possível criar o usuário');
    }
    return response.user!.id;
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      // Dev bypass might not have a real session
      print('SignOut: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    // Agora busca na nova tabela 'perfil' e junta as unidades da tabela 'unidades' via 'unidade_perfil'
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
  }

  @override
  Future<void> updateFcmToken(String userId, String token) async {
    await _supabase.from('perfil').update({'fcm_token': token}).eq('id', userId);
  }

  // Busca do Condomínio via AutoComplete (Trás id, nome, cidade, estado, logo, etc.)
  @override
  Future<List<Map<String, dynamic>>> searchCondominios(String query) async {
    return await _supabase
        .from('condominios')
        .select('id, nome, cidade, estado, tipo_estrutura')
        .ilike('nome', '%$query%')
        .order('nome')
        .limit(10);
  }

  // Busca de Blocos de um Condomínio Específico
  @override
  Future<List<Map<String, dynamic>>> getBlocos(String condominioId) async {
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
      return [];
    }
  }

  // Busca de Apartamentos de um Bloco Específico (via vínculo na tabela unidades)
  @override
  Future<List<Map<String, dynamic>>> getApartamentos(String condominioId, String blocoId) async {
    try {
      final response = await _supabase
          .from('unidades')
          .select('apartamento_id, apartamentos(numero)')
          .eq('condominio_id', condominioId)
          .eq('bloco_id', blocoId)
          .order('apartamentos(numero)');
          
      print('📦 [AuthRepo] getApartamentos: Encontradas ${response.length} unidades vinculadas ao bloco $blocoId');
      if (response.isEmpty) {
        print('⚠️ [AuthRepo] getApartamentos: Nenhuma unidade encontrada! Certifique-se de que clicou em "Gerar Unidades" na Tab 3 como Síndico.');
      }
          
      // Transform and handle potential List/Map variations from Supabase joins
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
      return [];
    }
  }

  @override
  Future<bool> isEmailAvailable(String email) async {
    try {
      final res = await _supabase.rpc(
        'check_email_exists',
        params: {'email_to_check': email.trim()},
      );
      
      // Se res for true, significa que o email EXISTE (por isso não está disponível)
      return res == false;
    } catch (e) {
      print('Erro ao chamar RPC check_email_exists: $e');
      // Rethrow para que a UI saiba que a checagem falhou e não deixe passar "falsos positivos"
      throw Exception('Não foi possível verificar a disponibilidade do e-mail no momento. Detalhe: $e');
    }
  }

  // Identifica a Unidade Exata (bloco_apto_id)
  @override
  Future<Map<String, dynamic>?> getUnidade(String condominioId, String blocoId, String apartamentoId) async {
    return await _supabase
        .from('unidades')
        .select()
        .eq('condominio_id', condominioId)
        .eq('bloco_id', blocoId)
        .eq('apartamento_id', apartamentoId)
        .maybeSingle();
  }

  // Processo Completo de Registro do Morador (Grava Perfil + Vínculo da Unidade)
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
    // Grava o Perfil
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

    // 2. Vincula com a Unidade (tabela unidade_perfil)
    if (unidadeId.isNotEmpty) {
      await _supabase.from('unidade_perfil').insert({
        'perfil_id': userId,
        'unidade_id': unidadeId,
      });
    }
  }

  // Processo Especial de Registro do Síndico + Novo Condomínio
  @override
  Future<void> registerSindico({
    required String userId,
    required String email,
    required Map<String, dynamic> condominioData,
    required String nomeCompleto,
    required String whatsapp,
  }) async {
    // Como isso envolve múltiplas tabelas críticas (Condomínio -> Bloco 0 -> Apto 0 -> Unidade -> Perfil),
    // é essencial garantir consistência.
    
    // 1. Cria o Condomínio
    final condominioResult = await _supabase.from('condominios').insert(condominioData).select().single();
    final condominioId = condominioResult['id'];
    
    // 2. Cria Bloco '0' e Apto '0' (Padrão Síndico/Administração)
    final blocoResult = await _supabase.from('blocos').insert({
      'condominio_id': condominioId,
      'nome_ou_numero': '0',
    }).select().single();
    
    final aptoResult = await _supabase.from('apartamentos').insert({
      'condominio_id': condominioId,
      'numero': '0',
    }).select().single();
    
    // 3. Cria a Unidade
    final unidadeResult = await _supabase.from('unidades').insert({
      'condominio_id': condominioId,
      'bloco_id': blocoResult['id'],
      'apartamento_id': aptoResult['id'],
    }).select().single();
    
    // 4. Cria o Perfil do Síndico (já aprovado automaticamente)
    await _supabase.from('perfil').insert({
      'id': userId,
      'condominio_id': condominioId,
      'nome_completo': nomeCompleto,
      'email': email,
      'whatsapp': whatsapp,
      'status_aprovacao': 'aprovado',
      'tipo_morador': 'Proprietário', // Assumido
      'papel_sistema': 'Síndico',
    });
    
    // 5. Vincula Síndico à Unidade 0-0
    await _supabase.from('unidade_perfil').insert({
      'perfil_id': userId,
      'unidade_id': unidadeResult['id'],
    });
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

}
