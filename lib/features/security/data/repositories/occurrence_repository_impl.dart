import 'dart:async';
import 'package:condomeet/core/errors/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:condomeet/features/security/domain/models/occurrence.dart';
import 'package:condomeet/features/security/domain/repositories/occurrence_repository.dart';

/// Uses Supabase directly (not PowerSync) to avoid sync_rules configuration
/// complexity and the condominium_id → condominio_id remapping bug in uploadData.
class OccurrenceRepositoryImpl implements OccurrenceRepository {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  Future<Result<void>> reportOccurrence({
    required String residentId,
    required String condominiumId,
    required String assunto,
    required String description,
    required OccurrenceCategory category,
    String? photoUrl,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return const Failure('Usuário não autenticado.');

      // Self-heal: if IDs are empty, fetch from profile
      String resolvedResidentId = residentId.isNotEmpty ? residentId : currentUser.id;
      String resolvedCondoId = condominiumId;

      if (resolvedCondoId.isEmpty) {
        final profile = await _supabase
            .from('perfil')
            .select('condominio_id')
            .eq('id', currentUser.id)
            .single();
        resolvedCondoId = (profile['condominio_id'] as String?) ?? '';
      }

      if (resolvedCondoId.isEmpty) {
        return const Failure('Condomínio não identificado. Faça login novamente.');
      }

      final id = const Uuid().v4();
      final now = DateTime.now().toIso8601String();

      await _supabase.from('ocorrencias').insert({
        'id': id,
        'resident_id': resolvedResidentId,
        'condominio_id': resolvedCondoId,
        'assunto': assunto,
        'description': description,
        'category': category.name,
        'status': 'pending',
        'photo_url': photoUrl,
        'created_at': now,
        'updated_at': now,
      });

      return const Success(null);
    } catch (e) {
      return Failure('Erro ao registrar ocorrência: ${e.toString()}');
    }
  }

  @override
  Stream<List<Occurrence>> watchResidentOccurrences(String residentId) async* {
    final userId = residentId.isNotEmpty
        ? residentId
        : (_supabase.auth.currentUser?.id ?? '');
    if (userId.isEmpty) { yield []; return; }

    final response = await _supabase
        .from('ocorrencias')
        .select()
        .eq('resident_id', userId)
        .order('created_at', ascending: false);

    yield (response as List)
        .map((row) => Occurrence.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Stream<List<Occurrence>> watchAllOccurrences(String condominiumId) async* {
    String resolvedCondoId = condominiumId;
    if (resolvedCondoId.isEmpty) {
      final uid = _supabase.auth.currentUser?.id;
      if (uid != null) {
        final profile = await _supabase.from('perfil').select('condominio_id').eq('id', uid).single();
        resolvedCondoId = (profile['condominio_id'] as String?) ?? '';
      }
    }
    if (resolvedCondoId.isEmpty) { yield []; return; }

    final response = await _supabase
        .from('ocorrencias')
        .select()
        .eq('condominio_id', resolvedCondoId)
        .order('created_at', ascending: false);

    yield (response as List)
        .map((row) => Occurrence.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Result<void>> updateOccurrenceStatus(
    String occurrenceId,
    OccurrenceStatus status,
  ) async {
    try {
      await _supabase.from('ocorrencias').update({
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', occurrenceId);
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao atualizar status: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> respondOccurrence({
    required String occurrenceId,
    required String response,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _supabase.from('ocorrencias').update({
        'admin_response': response,
        'admin_response_at': now,
        'status': 'resolved',
        'updated_at': now,
      }).eq('id', occurrenceId);
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao responder ocorrência: ${e.toString()}');
    }
  }
}
