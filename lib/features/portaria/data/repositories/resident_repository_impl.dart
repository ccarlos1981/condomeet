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

      // Use Supabase directly so the porter can search ALL residents of the
      // condo — not just those synced locally via PowerSync.
      final sanitizedQuery = '%${query.toLowerCase()}%';

      final response = await _supabase
          .from('perfil')
          .select('*, bloco_txt, apto_txt')
          .eq('condominio_id', condominiumId)
          .or('status_aprovacao.eq.aprovado')
          .inFilter('papel_sistema', ['Morador', 'resident', 'Síndico'])
          .or('nome_completo.ilike.$sanitizedQuery,apto_txt.ilike.$sanitizedQuery,bloco_txt.ilike.$sanitizedQuery')
          .limit(30);

      final allResidents = (response as List)
          .map((row) => Resident.fromMap(Map<String, dynamic>.from(row)))
          .toList();

      // Client-side accent-normalization filter for better matching
      final normalizedQuery = _normalize(query);
      final residents = allResidents.where((r) {
        final normalizedName = _normalize(r.fullName);
        final unit = (r.unitNumber ?? '').toLowerCase();
        final block = (r.block ?? '').toLowerCase();
        return normalizedName.contains(normalizedQuery) ||
            unit.contains(query.toLowerCase()) ||
            block.contains(query.toLowerCase());
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

  @override
  Future<Result<List<Resident>>> getAllResidents(String condominiumId) async {
    try {
      final response = await _supabase
          .from('perfil')
          .select('id, nome_completo, email, whatsapp, bloco_txt, apto_txt, papel_sistema, tipo_morador, status_aprovacao, created_at')
          .eq('condominio_id', condominiumId)
          .order('created_at', ascending: false);

      final rawList = response as List;
      final residents = rawList.map((row) => Resident.fromMap(Map<String, dynamic>.from(row))).toList();
      return Success(residents);
    } catch (e) {
      // Fallback to PowerSync
      try {
        final results = await _powerSync.db.getAll(
          '''
          SELECT id, nome_completo, email, whatsapp, bloco_txt, apto_txt, 
                 papel_sistema, tipo_morador, status_aprovacao, created_at
          FROM perfil
          WHERE condominio_id = ?
          ORDER BY created_at DESC
          ''',
          [condominiumId],
        );
        return Success(results.map((row) => Resident.fromMap(row)).toList());
      } catch (dbError) {
        return Failure('Erro ao buscar moradores: ${e.toString()}');
      }
    }
  }

  @override
  Future<Result<void>> blockResident(String residentId) async {
    try {
      await _supabase
          .from('perfil')
          .update({'status_aprovacao': 'bloqueado'})
          .eq('id', residentId);
      await _powerSync.db.execute(
        "UPDATE perfil SET status_aprovacao = 'bloqueado', updated_at = ? WHERE id = ?",
        [DateTime.now().toIso8601String(), residentId],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao bloquear morador: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> unblockResident(String residentId) async {
    try {
      await _supabase
          .from('perfil')
          .update({'status_aprovacao': 'aprovado'})
          .eq('id', residentId);
      await _powerSync.db.execute(
        "UPDATE perfil SET status_aprovacao = 'aprovado', updated_at = ? WHERE id = ?",
        [DateTime.now().toIso8601String(), residentId],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao desbloquear morador: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> updateResidentProfile({
    required String residentId,
    required String condominiumId,
    required String fullName,
    required String email,
    required String phone,
    required String block,
    required String unit,
    required String tipoMorador,
    required String papelSistema,
  }) async {
    try {
      final session = _authRepository.currentSession;
      if (session == null) return Failure('Sem autorização');

      final isTargetAdmin = papelSistema == 'Admin';
      final finalBlock = isTargetAdmin ? 'Admin' : block.trim();
      final finalUnit = isTargetAdmin ? 'Admin' : unit.trim();

      // 1. Update Perfil
      await _supabase.from('perfil').update({
        'nome_completo': fullName,
        'email': email,
        'whatsapp': phone,
        'bloco_txt': finalBlock,
        'apto_txt': finalUnit,
        'tipo_morador': tipoMorador,
        'papel_sistema': papelSistema,
      }).eq('id', residentId);
      
      // Update powersync locally for instant feedback
      try {
        await _powerSync.db.execute(
          '''
          UPDATE perfil SET 
            nome_completo = ?, email = ?, whatsapp = ?, bloco_txt = ?, apto_txt = ?, tipo_morador = ?, papel_sistema = ?, updated_at = ?
          WHERE id = ?
          ''',
          [fullName, email, phone, finalBlock, finalUnit, tipoMorador, papelSistema, DateTime.now().toIso8601String(), residentId]
        );
      } catch (_) {}

      // 2. Handle unit bindings directly on Supabase (preserving history)
      if (!isTargetAdmin && finalBlock.isNotEmpty && finalUnit.isNotEmpty && finalBlock != 'Admin') {
        // Find or create block
        String? blocoId;
        final blocoArr = await _supabase.from('blocos')
            .select('id').eq('condominio_id', condominiumId).eq('nome_ou_numero', finalBlock);
        if (blocoArr.isNotEmpty) {
          blocoId = blocoArr[0]['id'] as String;
        } else {
          final newBloco = await _supabase.from('blocos').insert({
            'condominio_id': condominiumId,
            'nome_ou_numero': finalBlock,
          }).select('id').single();
          blocoId = newBloco['id'] as String;
        }

        // Find or create apto
        String? aptoId;
        final aptoArr = await _supabase.from('apartamentos')
            .select('id').eq('condominio_id', condominiumId).eq('numero', finalUnit);
        if (aptoArr.isNotEmpty) {
          aptoId = aptoArr[0]['id'] as String;
        } else {
          final newApto = await _supabase.from('apartamentos').insert({
            'condominio_id': condominiumId,
            'numero': finalUnit,
          }).select('id').single();
          aptoId = newApto['id'] as String;
        }

        // Find or create physical unit (strictly schema columns)
        String? unidadeId;
        final unitArr = await _supabase.from('unidades')
            .select('id')
            .eq('condominio_id', condominiumId)
            .eq('bloco_id', blocoId)
            .eq('apartamento_id', aptoId);
        if (unitArr.isNotEmpty) {
          unidadeId = unitArr[0]['id'] as String;
        } else {
          final newUnit = await _supabase.from('unidades').insert({
            'condominio_id': condominiumId,
            'bloco_id': blocoId,
            'apartamento_id': aptoId,
          }).select('id').single();
          unidadeId = newUnit['id'] as String;
        }

        if (unidadeId.isNotEmpty) {
          final existingLinks = await _supabase.from('unidade_perfil')
              .select('id, unidade_id, status')
              .eq('perfil_id', residentId);
          
          final alreadyActive = (existingLinks as List).any((l) => l['unidade_id'] == unidadeId && l['status'] == 'ativo');
          
          if (!alreadyActive) {
            // Inactivate old active links to preserve history
            await _supabase.from('unidade_perfil')
                .update({
                  'status': 'inativo',
                  'data_saida': DateTime.now().toUtc().toIso8601String(),
                })
                .eq('perfil_id', residentId)
                .eq('status', 'ativo');
            
            // Insert or reactivate link with onConflict handling
            await _supabase.from('unidade_perfil').upsert({
              'perfil_id': residentId,
              'unidade_id': unidadeId,
              'status': 'ativo',
              'data_entrada': DateTime.now().toUtc().toIso8601String(),
              'data_saida': null,
            }, onConflict: 'perfil_id, unidade_id');
          }
        }
      }

      return const Success(null);
    } catch (e) {
      return Failure('Erro ao salvar morador: ${e.toString()}');
    }
  }

  @override
  Future<Result<void>> resetPassword(String residentId) async {
    try {
      await _supabase.rpc('admin_reset_password_by_sindico', params: {
        'target_user_id': residentId,
        'reset_password': '123456',
      });
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao resetar senha: ${e.toString()}');
    }
  }
}

