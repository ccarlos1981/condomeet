import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  Session? get currentSession;
  Future<void> signInWithEmail(String email, String password);
  Future<String> signUpWithEmail(String email, String password);
  Future<void> signOut();
  Future<Map<String, dynamic>?> fetchProfile(String userId);
  Future<void> updateFcmToken(String userId, String token);
  
  // Novos métodos de busca para o Cadastro 2.0
  Future<List<Map<String, dynamic>>> searchCondominios(String query);
  Future<List<Map<String, dynamic>>> getBlocos(String condominioId);
  Future<List<Map<String, dynamic>>> getApartamentos(String condominioId, String blocoId);
  Future<Map<String, dynamic>?> getUnidade(String condominioId, String blocoId, String apartamentoId);
  Future<bool> isEmailAvailable(String email);

  // Registro de Morador/Funcionário
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
  });

  // Registro de Síndico e Condomínio Simultâneo
  Future<void> registerSindico({
    required String userId,
    required String email,
    required Map<String, dynamic> condominioData,
    required String nomeCompleto,
    required String whatsapp,
  });

  // Password management
  Future<void> resetPasswordForEmail(String email);
  Future<void> updatePassword(String newPassword);
  
}
