import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/features/admin/domain/repositories/structure_repository.dart';
import 'package:condomeet/shared/models/bloco.dart';
import 'package:condomeet/shared/models/apartamento.dart';
import 'package:condomeet/shared/models/unidade.dart';
import './structure_event.dart';
import './structure_state.dart';

class StructureBloc extends Bloc<StructureEvent, StructureState> {
  final StructureRepository _structureRepository;
  StreamSubscription? _blocosSubscription;
  StreamSubscription? _apartamentosSubscription;
  StreamSubscription? _unidadesSubscription;

  StructureBloc({required StructureRepository structureRepository})
      : _structureRepository = structureRepository,
        super(const StructureState()) {
    on<StructureStarted>(_onStarted);
    on<BlocoAdded>(_onBlocoAdded);
    on<BlocoDeleted>(_onBlocoDeleted);
    on<ApartamentoAdded>(_onApartamentoAdded);
    on<ApartamentoDeleted>(_onApartamentoDeleted);
    on<UnidadesGenerated>(_onUnidadesGenerated);
    on<UnidadeDeleted>(_onUnidadeDeleted);
    on<WatchUnidadesStarted>(_onWatchUnidadesStarted);
    on<UnidadeAdded>(_onUnidadeAdded);
    on<_BlocosUpdated>(_onBlocosUpdated);
    on<_ApartamentosUpdated>(_onApartamentosUpdated);
    on<_UnidadesUpdated>(_onUnidadesUpdated);
    on<_StreamError>(_onStreamError);
  }

  Future<void> _onStarted(StructureStarted event, Emitter<StructureState> emit) async {
    emit(state.copyWith(status: StructureStatus.loading));

    await _blocosSubscription?.cancel();
    _blocosSubscription = _structureRepository.watchBlocos(event.condominiumId).listen(
      (blocos) => add(_BlocosUpdated(blocos)),
      onError: (e) => add(_StreamError(e.toString())),
    );

    await _apartamentosSubscription?.cancel();
    _apartamentosSubscription = _structureRepository.watchApartamentos(event.condominiumId).listen(
      (aptos) => add(_ApartamentosUpdated(aptos)),
      onError: (e) => add(_StreamError(e.toString())),
    );

    await _unidadesSubscription?.cancel();
    _unidadesSubscription = _structureRepository.watchUnidades(event.condominiumId).listen(
      (unidades) => add(_UnidadesUpdated(unidades)),
      onError: (e) => add(_StreamError(e.toString())),
    );
  }

  void _onBlocosUpdated(_BlocosUpdated event, Emitter<StructureState> emit) {
    emit(state.copyWith(status: StructureStatus.success, blocos: event.blocos));
  }

  void _onApartamentosUpdated(_ApartamentosUpdated event, Emitter<StructureState> emit) {
    emit(state.copyWith(status: StructureStatus.success, apartamentos: event.apartamentos));
  }

  void _onUnidadesUpdated(_UnidadesUpdated event, Emitter<StructureState> emit) {
    emit(state.copyWith(status: StructureStatus.success, unidades: event.unidades));
  }

  void _onStreamError(_StreamError event, Emitter<StructureState> emit) {
    emit(state.copyWith(status: StructureStatus.failure, errorMessage: _mapError(event.error)));
  }

  String _mapError(dynamic e) {
    final errorStr = e.toString();
    if (errorStr.contains('23503')) {
      return 'Não é possível excluir: existem moradores ou perfis vinculados a este item.';
    }
    if (errorStr.contains('23505')) {
      return 'Este item já cadastrado (conflito de duplicidade).';
    }
    if (errorStr.contains('network_error') || errorStr.contains('SocketException')) {
      return 'Erro de conexão. Verifique sua internet.';
    }
    // Simplifica mensagens genéricas feias
    if (errorStr.contains('PostgrestException')) {
      return 'Erro no banco de dados. Tente novamente em instantes.';
    }
    return 'Ops! Ocorreu um erro inesperado. Tente novamente.';
  }

  Future<void> _onBlocoAdded(BlocoAdded event, Emitter<StructureState> emit) async {
    try {
      await _structureRepository.addBloco(event.condominiumId, event.nomeOuNumero);
      emit(state.copyWith(errorMessage: null)); // Limpa erro anterior
    } catch (e) {
      emit(state.copyWith(status: StructureStatus.failure, errorMessage: _mapError(e)));
    }
  }

  Future<void> _onBlocoDeleted(BlocoDeleted event, Emitter<StructureState> emit) async {
    try {
      await _structureRepository.deleteBloco(event.blocoId);
      emit(state.copyWith(errorMessage: null));
    } catch (e) {
      emit(state.copyWith(status: StructureStatus.failure, errorMessage: _mapError(e)));
    }
  }

  Future<void> _onApartamentoAdded(ApartamentoAdded event, Emitter<StructureState> emit) async {
    try {
      await _structureRepository.addApartamento(event.condominiumId, event.numero);
      emit(state.copyWith(errorMessage: null));
    } catch (e) {
      emit(state.copyWith(status: StructureStatus.failure, errorMessage: _mapError(e)));
    }
  }

  Future<void> _onApartamentoDeleted(ApartamentoDeleted event, Emitter<StructureState> emit) async {
    try {
      await _structureRepository.deleteApartamento(event.apartamentoId);
      emit(state.copyWith(errorMessage: null));
    } catch (e) {
      emit(state.copyWith(status: StructureStatus.failure, errorMessage: _mapError(e)));
    }
  }

  Future<void> _onUnidadesGenerated(UnidadesGenerated event, Emitter<StructureState> emit) async {
    try {
      emit(state.copyWith(status: StructureStatus.loading, errorMessage: null));
      await _structureRepository.generateUnidades(
        condominiumId: event.condominiumId,
        blocoIds: event.blocoIds,
        apartamentoIds: event.apartamentoIds,
      );
      final total = event.blocoIds.length * event.apartamentoIds.length;
      emit(state.copyWith(
        status: StructureStatus.success,
        successMessage: '$total unidades processadas com sucesso!',
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(status: StructureStatus.failure, errorMessage: _mapError(e)));
    }
  }

  Future<void> _onUnidadeDeleted(UnidadeDeleted event, Emitter<StructureState> emit) async {
    try {
      await _structureRepository.deleteUnidade(event.unidadeId);
      emit(state.copyWith(errorMessage: null));
    } catch (e) {
      emit(state.copyWith(status: StructureStatus.failure, errorMessage: _mapError(e)));
    }
  }

  Future<void> _onWatchUnidadesStarted(WatchUnidadesStarted event, Emitter<StructureState> emit) async {
    emit(state.copyWith(status: StructureStatus.loading));

    await _unidadesSubscription?.cancel();
    _unidadesSubscription = _structureRepository.watchUnidades(event.condominiumId).listen(
      (unidades) {
        // Filter by blocoId for the block detail screen
        final filtered = unidades.where((u) => u.blocoId == event.blocoId).toList();
        add(_UnidadesUpdated(filtered));
      },
      onError: (e) => add(_StreamError(e.toString())),
    );
  }

  Future<void> _onUnidadeAdded(UnidadeAdded event, Emitter<StructureState> emit) async {
    try {
      await _structureRepository.addUnidade(event.condominiumId, event.blocoId, event.aptoNumero);
      emit(state.copyWith(errorMessage: null));
    } catch (e) {
      emit(state.copyWith(status: StructureStatus.failure, errorMessage: _mapError(e)));
    }
  }

  @override
  Future<void> close() {
    _blocosSubscription?.cancel();
    _apartamentosSubscription?.cancel();
    _unidadesSubscription?.cancel();
    return super.close();
  }
}

// ── Private stream events ──
class _BlocosUpdated extends StructureEvent {
  final List<Bloco> blocos;
  const _BlocosUpdated(this.blocos);
}

class _ApartamentosUpdated extends StructureEvent {
  final List<Apartamento> apartamentos;
  const _ApartamentosUpdated(this.apartamentos);
}

class _UnidadesUpdated extends StructureEvent {
  final List<Unidade> unidades;
  const _UnidadesUpdated(this.unidades);
}

class _StreamError extends StructureEvent {
  final String error;
  const _StreamError(this.error);
}
