import 'package:flutter/material.dart';

enum BroadcastPriority { normal, important, critical }

class Broadcast {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final BroadcastPriority priority;
  final bool isRead;

  Broadcast({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    this.priority = BroadcastPriority.normal,
    this.isRead = false,
  });

  Color get priorityColor {
    switch (priority) {
      case BroadcastPriority.critical:
        return Colors.red;
      case BroadcastPriority.important:
        return Colors.orange;
      case BroadcastPriority.normal:
        return const Color(0xFF6366F1);
    }
  }

  IconData get priorityIcon {
    switch (priority) {
      case BroadcastPriority.critical:
        return Icons.gavel;
      case BroadcastPriority.important:
        return Icons.notification_important;
      case BroadcastPriority.normal:
        return Icons.info_outline;
    }
  }
}
