import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:condomeet/features/security/domain/models/chat_message.dart';
import 'package:condomeet/features/security/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final PowerSyncService _powerSync;

  ChatRepositoryImpl(this._powerSync);

  @override
  Stream<List<ChatMessage>> watchMessages(String residentId) {
    return _powerSync.db.watch(
      '''
      SELECT c.*, p.full_name as sender_name
      FROM chat_messages c
      JOIN profiles p ON c.sender_id = p.id
      WHERE c.resident_id = ?
      ORDER BY c.created_at ASC
      ''',
      parameters: [residentId],
    ).map((rows) => rows.map((row) => ChatMessage.fromMap(row)).toList());
  }

  @override
  Stream<List<ChatMessage>> watchAllThreads(String condominiumId) {
    // This query gets the last message from each thread (grouped by resident_id)
    return _powerSync.db.watch(
      '''SELECT * FROM mensagens_chat 
        WHERE condominio_id = ? 
        ORDER BY created_at ASC''',
      parameters: [condominiumId],
    ).map((rows) => rows.map((row) => ChatMessage.fromMap(row)).toList());
  }

  @override
  Future<Result<void>> sendMessage({
    required String residentId,
    required String condominiumId,
    required String senderId,
    required MessageSenderRole senderRole,
    required String text,
  }) async {
    try {
      final id = const Uuid().v4();
      await _powerSync.db.execute(
        '''INSERT INTO mensagens_chat (id, resident_id, condominio_id, sender_id, sender_role, text, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          id,
          residentId,
          condominiumId,
          senderId,
          senderRole.name,
          text,
          DateTime.now().toIso8601String(),
          DateTime.now().toIso8601String(),
        ],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao enviar mensagem: ${e.toString()}');
    }
  }
}
