import 'package:condomeet/core/errors/result.dart';
import '../models/chat_message.dart';

abstract class ChatRepository {
  /// Watches the message stream for the official chat.
  Stream<List<ChatMessage>> watchMessages(String residentId);

  /// Sends a new message.
  Future<Result<void>> sendMessage({
    required String residentId,
    required String text,
  });
}
