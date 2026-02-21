import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/security/domain/models/broadcast.dart';

class BroadcastCard extends StatelessWidget {
  final Broadcast broadcast;
  final VoidCallback? onDismiss;

  const BroadcastCard({
    super.key,
    required this.broadcast,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isCritical = broadcast.priority == BroadcastPriority.critical;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCritical ? Colors.red.withValues(alpha: 0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCritical ? Colors.red : AppColors.border,
          width: isCritical ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  broadcast.priorityIcon,
                  color: broadcast.priorityColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    broadcast.title,
                    style: AppTypography.h3.copyWith(
                      color: isCritical ? Colors.red : AppColors.textMain,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    onPressed: onDismiss,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Text(
              broadcast.content,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
