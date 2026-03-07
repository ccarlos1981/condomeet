import 'package:condomeet/core/errors/result.dart';
import '../models/chat_message.dart';

abstract class ChatRepository {
  /// Watches the message stream for a specific resident thread.
  Stream<List<ChatMessage>> watchMessages(String residentId);

  /// Watches all unique threads in a condominium (Staff view).
  Stream<List<ChatMessage>> watchAllThreads(String condominiumId);

  /// Sends a new message.
  Future<Result<void>> sendMessage({
    required String residentId,
    required String condominiumId,
    required String senderId,
    required MessageSenderRole senderRole,
    required String text,
  });
}
