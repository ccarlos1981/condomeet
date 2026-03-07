import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';
import 'package:condomeet/features/auth/domain/repositories/auth_repository.dart';

/// Normalizes a string by removing diacritical marks (accents).
/// Example: "João" -> "joao", "Café" -> "cafe"
String _normalize(String input) {
  const withAccents    = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const withoutAccents = 'aaaaaeeeeiiiioooooouuuucnAAAAEEEEIIIIOOOOOUUUUCN';
  var result = input.toLowerCase();
  for (var i = 0; i < withAccents.length; i++) {
    result = result.replaceAll(withAccents[i], withoutAccents[i]);
  }
  return result;
}

class ResidentRepositoryImpl implements ResidentRepository {
  final PowerSyncService _powerSync;
  final SupabaseClient _supabase;
  final AuthRepository _authRepository;

  ResidentRepositoryImpl(this._powerSync, this._supabase, this._authRepository);

  @override
  Future<Result<List<Resident>>> searchResidents(String query, String condominiumId) async {
    try {
      if (query.isEmpty) {
        return const Success([]);
      }

      final sanitizedQuery = '%${query.toLowerCase()}%';

      final results = await _powerSync.db.getAll(
        '''
        SELECT 
          p.*, 
          p.bloco_txt as block, 
          p.apto_txt as unit_number, 
          u.bloqueada as is_blocked,
          u.id as unit_id
        FROM perfil p
        LEFT JOIN unidade_perfil up ON p.id = up.perfil_id
        LEFT JOIN unidades u ON up.unidade_id = u.id
        WHERE (LOWER(p.nome_completo) LIKE ? OR p.apto_txt LIKE ?) 
          AND p.condominio_id = ?
          AND (p.papel_sistema = 'Morador' OR p.papel_sistema = 'resident' OR p.papel_sistema = 'Síndico')
          AND p.status_aprovacao = 'aprovado'
        ''',
        [sanitizedQuery, sanitizedQuery, condominiumId],
      );

      final allResidents = results.map((row) => Resident.fromMap(row)).toList();
      final normalizedQuery = _normalize(query);
      final residents = allResidents.where((r) {
        final normalizedName = _normalize(r.fullName);
        final unit = (r.unitNumber ?? '').toLowerCase();
        return normalizedName.contains(normalizedQuery) ||
            unit.contains(query.toLowerCase());
      }).toList();

      return Success(residents);
    } catch (e) {
      return Failure('Erro ao buscar moradores: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> requestSelfRegistration({
    required String name,
    required String block,
    required String unit,
    String? photoPath,
    String? condominiumId,
  }) async {
    try {
      final session = _authRepository.currentSession;
      if (session == null) return Failure('Usuário não autenticado');

      String unitId;
      final existingUnit = await _powerSync.db.getOptional(
        'SELECT id FROM unidades WHERE condominio_id = ? AND bloco_txt = ? AND apto_txt = ?',
        [condominiumId, block, unit],
      );

      if (existingUnit != null) {
        unitId = existingUnit['id'] as String;
      } else {
        unitId = const Uuid().v4();
        await _powerSync.db.execute(
          'INSERT INTO unidades (id, condominio_id, bloco_txt, apto_txt, bloqueada, created_at) VALUES (?, ?, ?, ?, 0, ?)',
          [unitId, condominiumId, block, unit, DateTime.now().toIso8601String()],
        );
      }

      await _powerSync.db.execute(
        'INSERT INTO perfil (id, nome_completo, apto_txt, bloco_txt, papel_sistema, status_aprovacao, created_at, condominio_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [session.user.id, name, unit, block, 'Morador', 'pendente', DateTime.now().toIso8601String(), condominiumId],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao salvar cadastro: ${e.toString()}');
    }
  }

  @override
  Future<Result<List<Resident>>> getPendingResidents(String condominiumId) async {
    print('📦 [ResidentRepo] getPendingResidents: Início da busca para o condomínio: $condominiumId');
    try {
      // Proactive Sync: Fetch from Supabase directly to ensure we see new pendings
      // Simplified select to avoid join issues while debugging
      final response = await _supabase
          .from('perfil')
          .select('''
            *,
            unidade_perfil(
              unidade_id
            )
          ''')
          .eq('status_aprovacao', 'pendente')
          .eq('condominio_id', condominiumId)
          .order('created_at', ascending: false);
      
      final rawList = response as List;
      print('📦 [ResidentRepo] Supabase retornou ${rawList.length} registros pendentes.');

      final List<Resident> residents = rawList.map((row) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(row);
        print('👤 [ResidentRepo] Pendente encontrado: ${data['nome_completo']} | ID: ${data['id']}');
        
        // Handle units if they exist
        if (data['unidade_perfil'] != null && (data['unidade_perfil'] as List).isNotEmpty) {
          data['unit_id'] = (data['unidade_perfil'] as List).first['unidade_id'];
        }
        
        return Resident.fromMap(data);
      }).toList();

      return Success(residents);
    } catch (e) {
      print('❌ getPendingResidents error: $e');
      try {
        final results = await _powerSync.db.getAll(
          '''
          SELECT 
            p.*, 
            p.bloco_txt as block, 
            p.apto_txt as unit_number, 
            u.bloqueada as is_blocked,
            u.id as unit_id
          FROM perfil p
          LEFT JOIN unidade_perfil up ON p.id = up.perfil_id
          LEFT JOIN unidades u ON up.unidade_id = u.id
          WHERE p.status_aprovacao = 'pendente' AND p.condominio_id = ?
          ORDER BY p.created_at DESC
          ''',
          [condominiumId],
        );
        return Success(results.map((row) => Resident.fromMap(row)).toList());
      } catch (dbError) {
        return Failure('Erro ao buscar pendentes: ${e.toString()}');
      }
    }
  }

  @override
  Future<Result<void>> approveResident(String residentId) async {
    try {
      await _supabase
          .from('perfil')
          .update({'status_aprovacao': 'aprovado'})
          .eq('id', residentId);
          
      // Local fallback for offline support
      await _powerSync.db.execute(
        "UPDATE perfil SET status_aprovacao = 'aprovado', updated_at = ? WHERE id = ?",
        [DateTime.now().toIso8601String(), residentId],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao aprovar morador: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> rejectResident(String residentId) async {
    try {
      await _supabase
          .from('perfil')
          .update({'status_aprovacao': 'rejeitado'})
          .eq('id', residentId);

      await _powerSync.db.execute(
        "UPDATE perfil SET status_aprovacao = 'rejeitado', updated_at = ? WHERE id = ?",
        [DateTime.now().toIso8601String(), residentId],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao rejeitar morador: ${e.toString()}');
    }
  }
}
