part of 'assembly_bloc.dart';

abstract class AssemblyEvent extends Equatable {
  const AssemblyEvent();

  @override
  List<Object?> get props => [];
}

class WatchAssembliesRequested extends AssemblyEvent {
  final String condominiumId;
  const WatchAssembliesRequested(this.condominiumId);

  @override
  List<Object?> get props => [condominiumId];
}

class WatchAssemblyDetailsRequested extends AssemblyEvent {
  final String assemblyId;
  const WatchAssemblyDetailsRequested(this.assemblyId);

  @override
  List<Object?> get props => [assemblyId];
}

class CreateAssemblyRequested extends AssemblyEvent {
  final Assembly assembly;
  final List<String> optionTitles;

  const CreateAssemblyRequested({
    required this.assembly,
    required this.optionTitles,
  });

  @override
  List<Object?> get props => [assembly, optionTitles];
}

class CastVoteRequested extends AssemblyEvent {
  final String assemblyId;
  final String optionId;
  final String residentId;

  const CastVoteRequested({
    required this.assemblyId,
    required this.optionId,
    required this.residentId,
  });

  @override
  List<Object?> get props => [assemblyId, optionId, residentId];
}

class UpdateAssemblyStatusRequested extends AssemblyEvent {
  final String assemblyId;
  final AssemblyStatus status;

  const UpdateAssemblyStatusRequested({
    required this.assemblyId,
    required this.status,
  });

  @override
  List<Object?> get props => [assemblyId, status];
}

class _UpdateAssemblies extends AssemblyEvent {
  final List<Assembly> assemblies;
  const _UpdateAssemblies(this.assemblies);

  @override
  List<Object?> get props => [assemblies];
}

class _UpdateAssembliesError extends AssemblyEvent {
  final String error;
  const _UpdateAssembliesError(this.error);

  @override
  List<Object?> get props => [error];
}

class _UpdateAssemblyDetails extends AssemblyEvent {
  final List<AssemblyOption> options;
  final List<AssemblyVote> votes;

  const _UpdateAssemblyDetails({required this.options, required this.votes});

  @override
  List<Object?> get props => [options, votes];
}
