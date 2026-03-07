enum MessageSenderRole { admin, porter, resident }

class ChatMessage {
  final String id;
  final String residentId;
  final String condominiumId;
  final String senderId;
  final MessageSenderRole senderRole;
  final String text;
  final DateTime timestamp;
  final String? senderName;

  ChatMessage({
    required this.id,
    required this.residentId,
    required this.condominiumId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.timestamp,
    this.senderName,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      residentId: map['resident_id'],
      condominiumId: map['condominio_id'] ?? map['condominium_id'],
      senderId: map['sender_id'],
      senderRole: MessageSenderRole.values.firstWhere(
        (e) => e.name == map['sender_role'],
        orElse: () => MessageSenderRole.resident,
      ),
      text: map['text'],
      timestamp: DateTime.parse(map['created_at']),
      senderName: map['sender_name'], // Optional, might need a join
    );
  }

  bool get isFromResident => senderRole == MessageSenderRole.resident;
}
