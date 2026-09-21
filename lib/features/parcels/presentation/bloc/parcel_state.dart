import 'package:equatable/equatable.dart';
import '../../../portaria/domain/entities/parcel.dart';

abstract class ParcelState extends Equatable {
  const ParcelState();

  @override
  List<Object?> get props => [];
}

class ParcelInitial extends ParcelState {}

class ParcelLoading extends ParcelState {}

class ParcelLoaded extends ParcelState {
  final List<Parcel> pendingParcels;
  final List<Parcel> historyParcels;
  final bool isPersonal;

  const ParcelLoaded({
    this.pendingParcels = const [],
    this.historyParcels = const [],
    this.isPersonal = true,
  });

  @override
  List<Object?> get props => [pendingParcels, historyParcels, isPersonal];

  ParcelLoaded copyWith({
    List<Parcel>? pendingParcels,
    List<Parcel>? historyParcels,
    bool? isPersonal,
  }) {
    return ParcelLoaded(
      pendingParcels: pendingParcels ?? this.pendingParcels,
      historyParcels: historyParcels ?? this.historyParcels,
      isPersonal: isPersonal ?? this.isPersonal,
    );
  }
}

class ParcelError extends ParcelState {
  final String message;
  const ParcelError(this.message);

  @override
  List<Object?> get props => [message];
}
