import 'package:equatable/equatable.dart';
import '../../domain/models/occurrence.dart';

abstract class OccurrenceState extends Equatable {
  const OccurrenceState();
  
  @override
  List<Object?> get props => [];
}

class OccurrenceInitial extends OccurrenceState {}

class OccurrenceLoading extends OccurrenceState {}

class OccurrenceLoaded extends OccurrenceState {
  final List<Occurrence> occurrences;

  const OccurrenceLoaded(this.occurrences);

  @override
  List<Object?> get props => [occurrences];
}

class OccurrenceSuccess extends OccurrenceState {}

class OccurrenceError extends OccurrenceState {
  final String message;

  const OccurrenceError(this.message);

  @override
  List<Object?> get props => [message];
}
