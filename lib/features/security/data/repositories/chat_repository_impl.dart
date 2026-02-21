import 'dart:async';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/security/domain/models/chat_message.dart';
import 'package:condomeet/features/security/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final _messagesController = StreamController<List<ChatMessage>>.broadcast();
  final List<ChatMessage> _messages = [
    ChatMessage(
      id: '1',
      text: 'Olá! Como podemos ajudar hoje?',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      sender: MessageSender.administration,
      senderName: 'Administração',
    ),
  ];

  ChatRepositoryImpl() {
    _messagesController.add(List.from(_messages));
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String residentId) {
    return _messagesController.stream;
  }

  @override
  Future<Result<void>> sendMessage({
    required String residentId,
    required String text,
  }) async {
    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
      sender: MessageSender.resident,
      senderName: 'Cristiano Carlos',
    );

    _messages.add(newMessage);
    _messagesController.add(List.from(_messages));

    // Simulate auto-reply from Admin
    _simulateAdminReply();

    return const Success(null);
  }

  void _simulateAdminReply() {
    Future.delayed(const Duration(seconds: 2), () {
      final reply = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: 'Obrigado pelo contato. Recebemos sua mensagem e um atendente falará com você em breve.',
        timestamp: DateTime.now(),
        sender: MessageSender.administration,
        senderName: 'Administração',
      );
      _messages.add(reply);
      _messagesController.add(List.from(_messages));
    });
  }

  void dispose() {
    _messagesController.close();
  }
}

// Global instance for mock
final chatRepository = ChatRepositoryImpl();
