import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:condomeet/features/admin/domain/models/assembly.dart';
import 'package:condomeet/features/admin/domain/repositories/assembly_repository.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/core/utils/error_sanitizer.dart';
import 'package:rxdart/rxdart.dart';

part 'assembly_event.dart';
part 'assembly_state.dart';

class AssemblyBloc extends Bloc<AssemblyEvent, AssemblyState> {
  final AssemblyRepository _assemblyRepository;
  StreamSubscription? _assembliesSubscription;
  StreamSubscription? _detailsSubscription;

  AssemblyBloc({required AssemblyRepository assemblyRepository})
      : _assemblyRepository = assemblyRepository,
        super(AssemblyInitial()) {
    on<WatchAssembliesRequested>(_onWatchAssembliesRequested);
    on<WatchAssemblyDetailsRequested>(_onWatchAssemblyDetailsRequested);
    on<CreateAssemblyRequested>(_onCreateAssemblyRequested);
    on<CastVoteRequested>(_onCastVoteRequested);
    on<UpdateAssemblyStatusRequested>(_onUpdateAssemblyStatusRequested);
    on<_UpdateAssemblies>(_onUpdateAssemblies);
    on<_UpdateAssemblyDetails>(_onUpdateAssemblyDetails);
  }

  Future<void> _onWatchAssembliesRequested(
    WatchAssembliesRequested event,
    Emitter<AssemblyState> emit,
  ) async {
    emit(AssemblyLoading());
    await _assembliesSubscription?.cancel();
    _assembliesSubscription = _assemblyRepository
        .watchAssemblies(event.condominiumId)
        .listen((assemblies) => add(_UpdateAssemblies(assemblies)));
  }

  Future<void> _onWatchAssemblyDetailsRequested(
    WatchAssemblyDetailsRequested event,
    Emitter<AssemblyState> emit,
  ) async {
    emit(AssemblyLoading());
    await _detailsSubscription?.cancel();
    
    _detailsSubscription = Rx.combineLatest2(
      _assemblyRepository.watchOptions(event.assemblyId),
      _assemblyRepository.watchVotes(event.assemblyId),
      (options, votes) => (options, votes),
    ).listen((data) {
      add(_UpdateAssemblyDetails(options: data.$1, votes: data.$2));
    });
  }

  Future<void> _onCreateAssemblyRequested(
    CreateAssemblyRequested event,
    Emitter<AssemblyState> emit,
  ) async {
    emit(AssemblyLoading());
    final result = await _assemblyRepository.createAssembly(
      assembly: event.assembly,
      optionTitles: event.optionTitles,
    );
    if (result is Success) {
      emit(const AssemblySuccess('Assembleia criada com sucesso!'));
    } else {
      emit(AssemblyError(ErrorSanitizer.sanitize((result as Failure).message)));
    }
  }

  Future<void> _onCastVoteRequested(
    CastVoteRequested event,
    Emitter<AssemblyState> emit,
  ) async {
    emit(AssemblyLoading());
    final result = await _assemblyRepository.castVote(
      assemblyId: event.assemblyId,
      optionId: event.optionId,
      residentId: event.residentId,
    );
    if (result is Success) {
      emit(const AssemblySuccess('Voto registrado com sucesso!'));
    } else {
      emit(AssemblyError(ErrorSanitizer.sanitize((result as Failure).message)));
    }
  }

  Future<void> _onUpdateAssemblyStatusRequested(
    UpdateAssemblyStatusRequested event,
    Emitter<AssemblyState> emit,
  ) async {
    emit(AssemblyLoading());
    final result = await _assemblyRepository.updateStatus(event.assemblyId, event.status);
    if (result is Success) {
      emit(const AssemblySuccess('Status atualizado com sucesso!'));
    } else {
      emit(AssemblyError(ErrorSanitizer.sanitize((result as Failure).message)));
    }
  }

  void _onUpdateAssemblies(
    _UpdateAssemblies event,
    Emitter<AssemblyState> emit,
  ) {
    emit(AssembliesLoaded(event.assemblies));
  }

  void _onUpdateAssemblyDetails(
    _UpdateAssemblyDetails event,
    Emitter<AssemblyState> emit,
  ) {
    emit(AssemblyDetailsLoaded(options: event.options, votes: event.votes));
  }

  @override
  Future<void> close() {
    _assembliesSubscription?.cancel();
    _detailsSubscription?.cancel();
    return super.close();
  }
}
