import 'package:equatable/equatable.dart';
import '../../domain/models/occurrence.dart';

abstract class OccurrenceEvent extends Equatable {
  const OccurrenceEvent();

  @override
  List<Object?> get props => [];
}

class ReportOccurrenceRequested extends OccurrenceEvent {
  final String residentId;
  final String condominiumId;
  final String description;
  final OccurrenceCategory category;
  final List<String> photoPaths;

  const ReportOccurrenceRequested({
    required this.residentId,
    required this.condominiumId,
    required this.description,
    required this.category,
    this.photoPaths = const [],
  });

  @override
  List<Object?> get props => [residentId, condominiumId, description, category, photoPaths];
}

class WatchResidentOccurrencesRequested extends OccurrenceEvent {
  final String residentId;

  const WatchResidentOccurrencesRequested(this.residentId);

  @override
  List<Object?> get props => [residentId];
}

class WatchAllOccurrencesRequested extends OccurrenceEvent {
  final String condominiumId;

  const WatchAllOccurrencesRequested(this.condominiumId);

  @override
  List<Object?> get props => [condominiumId];
}

class UpdateOccurrenceStatusRequested extends OccurrenceEvent {
  final String occurrenceId;
  final OccurrenceStatus status;

  const UpdateOccurrenceStatusRequested({
    required this.occurrenceId,
    required this.status,
  });

  @override
  List<Object?> get props => [occurrenceId, status];
}

class _UpdateOccurrences extends OccurrenceEvent {
  final List<Occurrence> occurrences;

  const _UpdateOccurrences(this.occurrences);

  @override
  List<Object?> get props => [occurrences];
}
