import 'package:equatable/equatable.dart';
import 'package:condomeet/shared/models/bloco.dart';
import 'package:condomeet/shared/models/apartamento.dart';
import 'package:condomeet/shared/models/unidade.dart';

enum StructureStatus { initial, loading, success, failure }

class StructureState extends Equatable {
  final StructureStatus status;
  final List<Bloco> blocos;
  final List<Apartamento> apartamentos;
  final List<Unidade> unidades;
  final String? errorMessage;
  final String? successMessage;

  const StructureState({
    this.status = StructureStatus.initial,
    this.blocos = const [],
    this.apartamentos = const [],
    this.unidades = const [],
    this.errorMessage,
    this.successMessage,
  });

  StructureState copyWith({
    StructureStatus? status,
    List<Bloco>? blocos,
    List<Apartamento>? apartamentos,
    List<Unidade>? unidades,
    String? errorMessage,
    String? successMessage,
  }) {
    return StructureState(
      status: status ?? this.status,
      blocos: blocos ?? this.blocos,
      apartamentos: apartamentos ?? this.apartamentos,
      unidades: unidades ?? this.unidades,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [status, blocos, apartamentos, unidades, errorMessage, successMessage];
}
