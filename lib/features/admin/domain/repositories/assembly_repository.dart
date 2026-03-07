import 'package:condomeet/core/errors/result.dart';
import '../models/assembly.dart';

abstract class AssemblyRepository {
  /// Watches all assemblies for a condominium.
  Stream<List<Assembly>> watchAssemblies(String condominiumId);

  /// Watches options for a specific assembly.
  Stream<List<AssemblyOption>> watchOptions(String assemblyId);

  /// Watches votes for an assembly (results).
  Stream<List<AssemblyVote>> watchVotes(String assemblyId);

  /// Creates a new assembly with its options.
  Future<Result<void>> createAssembly({
    required Assembly assembly,
    required List<String> optionTitles,
  });

  /// Casts a vote.
  Future<Result<void>> castVote({
    required String assemblyId,
    required String optionId,
    required String residentId,
  });

  /// Updates assembly status (e.g., closing it).
  Future<Result<void>> updateStatus(String assemblyId, AssemblyStatus status);
}
