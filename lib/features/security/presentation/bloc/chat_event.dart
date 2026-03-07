import 'package:equatable/equatable.dart';
import '../../domain/models/chat_message.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class SendMessageRequested extends ChatEvent {
  final String residentId;
  final String condominiumId;
  final String senderId;
  final MessageSenderRole senderRole;
  final String text;

  const SendMessageRequested({
    required this.residentId,
    required this.condominiumId,
    required this.senderId,
    required this.senderRole,
    required this.text,
  });

  @override
  List<Object?> get props => [residentId, condominiumId, senderId, senderRole, text];
}

class WatchMessagesRequested extends ChatEvent {
  final String residentId;

  const WatchMessagesRequested(this.residentId);

  @override
  List<Object?> get props => [residentId];
}

class WatchAllThreadsRequested extends ChatEvent {
  final String condominiumId;

  const WatchAllThreadsRequested(this.condominiumId);

  @override
  List<Object?> get props => [condominiumId];
}

class _UpdateChatMessages extends ChatEvent {
  final List<ChatMessage> messages;

  const _UpdateChatMessages(this.messages);

  @override
  List<Object?> get props => [messages];
}

class _UpdateChatThreads extends ChatEvent {
  final List<ChatMessage> threads;

  const _UpdateChatThreads(this.threads);

  @override
  List<Object?> get props => [threads];
}
