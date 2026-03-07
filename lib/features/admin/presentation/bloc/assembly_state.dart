part of 'assembly_bloc.dart';

abstract class AssemblyState extends Equatable {
  const AssemblyState();
  
  @override
  List<Object?> get props => [];
}

class AssemblyInitial extends AssemblyState {}

class AssemblyLoading extends AssemblyState {}

class AssembliesLoaded extends AssemblyState {
  final List<Assembly> assemblies;
  const AssembliesLoaded(this.assemblies);

  @override
  List<Object?> get props => [assemblies];
}

class AssemblyDetailsLoaded extends AssemblyState {
  final List<AssemblyOption> options;
  final List<AssemblyVote> votes;
  const AssemblyDetailsLoaded({required this.options, required this.votes});

  @override
  List<Object?> get props => [options, votes];
}

class AssemblySuccess extends AssemblyState {
  final String message;
  const AssemblySuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class AssemblyError extends AssemblyState {
  final String message;
  const AssemblyError(this.message);

  @override
  List<Object?> get props => [message];
}
