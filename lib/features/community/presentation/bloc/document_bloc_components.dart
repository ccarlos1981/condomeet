import 'package:equatable/equatable.dart';
import 'package:condomeet/features/community/domain/models/document.dart';

abstract class DocumentState extends Equatable {
  const DocumentState();
  
  @override
  List<Object?> get props => [];
}

class DocumentInitial extends DocumentState {}

class DocumentLoading extends DocumentState {}

class DocumentLoaded extends DocumentState {
  final List<CondoDocument> documents;
  const DocumentLoaded(this.documents);

  @override
  List<Object?> get props => [documents];
}

class DocumentError extends DocumentState {
  final String message;
  const DocumentError(this.message);

  @override
  List<Object?> get props => [message];
}

abstract class DocumentEvent extends Equatable {
  const DocumentEvent();

  @override
  List<Object?> get props => [];
}

class WatchDocumentsRequested extends DocumentEvent {
  final String condominiumId;
  const WatchDocumentsRequested(this.condominiumId);

  @override
  List<Object?> get props => [condominiumId];
}

// ignore: unused_element
class _UpdateDocuments extends DocumentEvent {
  final List<CondoDocument> documents;
  const _UpdateDocuments(this.documents);

  @override
  List<Object?> get props => [documents];
}
