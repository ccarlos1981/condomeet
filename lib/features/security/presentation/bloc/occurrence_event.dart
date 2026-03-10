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
  final String assunto;
  final String description;
  final OccurrenceCategory category;
  final String? photoUrl;

  const ReportOccurrenceRequested({
    required this.residentId,
    required this.condominiumId,
    required this.assunto,
    required this.description,
    required this.category,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [residentId, condominiumId, assunto, description, category, photoUrl];
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

class RespondOccurrenceRequested extends OccurrenceEvent {
  final String occurrenceId;
  final String response;

  const RespondOccurrenceRequested({
    required this.occurrenceId,
    required this.response,
  });

  @override
  List<Object?> get props => [occurrenceId, response];
}


