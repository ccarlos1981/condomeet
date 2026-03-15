import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:condomeet/features/admin/domain/models/assembly.dart';
import 'package:condomeet/features/admin/domain/repositories/assembly_repository.dart';
import 'package:uuid/uuid.dart';

class AssemblyRepositoryImpl implements AssemblyRepository {
  final PowerSyncService _powerSyncService;

  AssemblyRepositoryImpl(this._powerSyncService);

  @override
  Stream<List<Assembly>> watchAssemblies(String condominiumId) {
    return _powerSyncService.db.watch(
      'SELECT * FROM assembleias WHERE condominio_id = ? ORDER BY data_inicio DESC',
      parameters: [condominiumId],
    ).map((rows) => rows.map((row) => Assembly.fromMap(row)).toList());
  }

  @override
  Stream<List<AssemblyOption>> watchOptions(String assemblyId) {
    return _powerSyncService.db.watch(
      'SELECT * FROM opcoes_assembleia WHERE assembleia_id = ?',
      parameters: [assemblyId],
    ).map((rows) => rows.map((row) => AssemblyOption.fromMap(row)).toList());
  }

  @override
  Stream<List<AssemblyVote>> watchVotes(String assemblyId) {
    return _powerSyncService.db.watch(
      'SELECT * FROM votos_assembleia WHERE assembleia_id = ?',
      parameters: [assemblyId],
    ).map((rows) => rows.map((row) => AssemblyVote.fromMap(row)).toList());
  }

  @override
  Future<Result<void>> createAssembly({
    required Assembly assembly,
    required List<String> optionTitles,
  }) async {
    try {
      await _powerSyncService.db.writeTransaction((tx) async {
        final assemblyId = const Uuid().v4();
        // 1. Create assembly
        await tx.execute(
          '''INSERT INTO assembleias (id, condominio_id, titulo, descricao, data_inicio, data_fim, status, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            assemblyId,
            assembly.condominiumId,
            assembly.title,
            assembly.description ?? '',
            assembly.startDate.toIso8601String(),
            assembly.endDate.toIso8601String(),
            'scheduled',
            DateTime.now().toIso8601String(),
          ],
        );

        // 2. Create options
        for (final optionTitle in optionTitles) {
          await tx.execute(
            'INSERT INTO opcoes_assembleia (id, assembleia_id, titulo, created_at) VALUES (?, ?, ?, ?)',
            [const Uuid().v4(), assemblyId, optionTitle, DateTime.now().toIso8601String()],
          );
        }
      });
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao criar assembleia: $e');
    }
  }

  @override
  Future<Result<void>> castVote({
    required String assemblyId,
    required String optionId,
    required String residentId,
  }) async {
    try {
      // 1. Check for double voting
      final existing = await _powerSyncService.db.getOptional(
        'SELECT id FROM votos_assembleia WHERE assembleia_id = ? AND perfil_id = ?',
        [assemblyId, residentId],
      );

      if (existing != null) {
        return const Failure('Você já votou nesta assembleia.');
      }

      await _powerSyncService.db.execute(
        'INSERT INTO votos_assembleia (id, assembleia_id, option_id, perfil_id, created_at) VALUES (?, ?, ?, ?, ?)',
        [const Uuid().v4(), assemblyId, optionId, residentId, DateTime.now().toIso8601String()],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao registrar voto: $e');
    }
  }

  @override
  Future<Result<void>> updateStatus(String assemblyId, AssemblyStatus status) async {
    try {
      await _powerSyncService.db.execute(
        'UPDATE assembleias SET status = ? WHERE id = ?',
        [status.name, assemblyId],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao atualizar status da assembleia: $e');
    }
  }
}
