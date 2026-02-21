enum MessageSender { resident, administration }

class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final MessageSender sender;
  final String senderName;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.sender,
    required this.senderName,
  });

  bool get isFromResident => sender == MessageSender.resident;
}
