import 'package:equatable/equatable.dart';

abstract class StructureEvent extends Equatable {
  const StructureEvent();
  @override
  List<Object?> get props => [];
}

// ── Lifecycle ──
class StructureStarted extends StructureEvent {
  final String condominiumId;
  const StructureStarted(this.condominiumId);
  @override
  List<Object?> get props => [condominiumId];
}

// ── Blocos ──
class BlocoAdded extends StructureEvent {
  final String condominiumId;
  final String nomeOuNumero;
  const BlocoAdded({required this.condominiumId, required this.nomeOuNumero});
  @override
  List<Object?> get props => [condominiumId, nomeOuNumero];
}

class BlocoDeleted extends StructureEvent {
  final String blocoId;
  const BlocoDeleted(this.blocoId);
  @override
  List<Object?> get props => [blocoId];
}

// ── Apartamentos ──
class ApartamentoAdded extends StructureEvent {
  final String condominiumId;
  final String numero;
  const ApartamentoAdded({required this.condominiumId, required this.numero});
  @override
  List<Object?> get props => [condominiumId, numero];
}

class ApartamentoDeleted extends StructureEvent {
  final String apartamentoId;
  const ApartamentoDeleted(this.apartamentoId);
  @override
  List<Object?> get props => [apartamentoId];
}

// ── Unidades ──
class UnidadesGenerated extends StructureEvent {
  final String condominiumId;
  final List<String> blocoIds;
  final List<String> apartamentoIds;
  const UnidadesGenerated({
    required this.condominiumId,
    required this.blocoIds,
    required this.apartamentoIds,
  });
  @override
  List<Object?> get props => [condominiumId, blocoIds, apartamentoIds];
}

class UnidadeDeleted extends StructureEvent {
  final String unidadeId;
  const UnidadeDeleted(this.unidadeId);
  @override
  List<Object?> get props => [unidadeId];
}
