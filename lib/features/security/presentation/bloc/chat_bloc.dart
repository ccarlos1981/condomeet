import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/models/chat_message.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _chatRepository;
  StreamSubscription? _chatSubscription;

  ChatBloc({required ChatRepository chatRepository})
      : _chatRepository = chatRepository,
        super(ChatInitial()) {
    on<SendMessageRequested>(_onSendMessageRequested);
    on<WatchMessagesRequested>(_onWatchMessagesRequested);
    on<WatchAllThreadsRequested>(_onWatchAllThreadsRequested);
    on<_UpdateChatMessages>(_onUpdateChatMessages);
    on<_UpdateChatThreads>(_onUpdateChatThreads);
  }

  Future<void> _onSendMessageRequested(SendMessageRequested event, Emitter<ChatState> emit) async {
    final result = await _chatRepository.sendMessage(
      residentId: event.residentId,
      condominiumId: event.condominiumId,
      senderId: event.senderId,
      senderRole: event.senderRole,
      text: event.text,
    );

    if (result.isFailure) {
      emit(ChatError(result.failureMessage));
    }
  }

  Future<void> _onWatchMessagesRequested(WatchMessagesRequested event, Emitter<ChatState> emit) async {
    await _chatSubscription?.cancel();
    _chatSubscription = _chatRepository.watchMessages(event.residentId).listen(
      (messages) => add(_UpdateChatMessages(messages)),
    );
  }

  Future<void> _onWatchAllThreadsRequested(WatchAllThreadsRequested event, Emitter<ChatState> emit) async {
    await _chatSubscription?.cancel();
    _chatSubscription = _chatRepository.watchAllThreads(event.condominiumId).listen(
      (threads) => add(_UpdateChatThreads(threads)),
    );
  }

  void _onUpdateChatMessages(_UpdateChatMessages event, Emitter<ChatState> emit) {
    emit(ChatMessagesLoaded(event.messages));
  }

  void _onUpdateChatThreads(_UpdateChatThreads event, Emitter<ChatState> emit) {
    emit(ChatThreadsLoaded(event.threads));
  }

  @override
  Future<void> close() {
    _chatSubscription?.cancel();
    return super.close();
  }
}

class _UpdateChatMessages extends ChatEvent {
  final List<ChatMessage> messages;
  const _UpdateChatMessages(this.messages);
}

class _UpdateChatThreads extends ChatEvent {
  final List<ChatMessage> threads;
  const _UpdateChatThreads(this.threads);
}
