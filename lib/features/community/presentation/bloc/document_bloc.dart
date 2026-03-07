import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/features/community/domain/repositories/document_repository.dart';
import 'package:condomeet/features/community/domain/models/document.dart';
import 'document_bloc_components.dart';

class DocumentBloc extends Bloc<DocumentEvent, DocumentState> {
  final DocumentRepository _documentRepository;
  StreamSubscription? _documentsSubscription;

  DocumentBloc({required DocumentRepository documentRepository})
      : _documentRepository = documentRepository,
        super(DocumentInitial()) {
    on<WatchDocumentsRequested>(_onWatchDocumentsRequested);
    on<_UpdateDocuments>(_onUpdateDocuments);
  }

  Future<void> _onWatchDocumentsRequested(
    WatchDocumentsRequested event,
    Emitter<DocumentState> emit,
  ) async {
    emit(DocumentLoading());
    await _documentsSubscription?.cancel();
    _documentsSubscription = _documentRepository
        .watchDocuments(event.condominiumId)
        .listen((documents) => add(_UpdateDocuments(documents)));
  }

  void _onUpdateDocuments(
    _UpdateDocuments event,
    Emitter<DocumentState> emit,
  ) {
    emit(DocumentLoaded(event.documents));
  }

  @override
  Future<void> close() {
    _documentsSubscription?.cancel();
    return super.close();
  }
}

class _UpdateDocuments extends DocumentEvent {
  final List<CondoDocument> documents;
  const _UpdateDocuments(this.documents);
}
