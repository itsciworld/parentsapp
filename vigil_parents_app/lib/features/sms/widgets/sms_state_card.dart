import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';

/// Two slim, separately-outlined stat boxes above the thread list:
/// number of conversations (threads) and total messages across them.
class SmsStateCard extends StatelessWidget {
  final int threads;
  final int messages;

  const SmsStateCard({super.key, this.threads = 0, this.messages = 0});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            icon: Icons.forum_rounded,
            color: AppColors.blueIcon,
            count: threads,
            label: 'Chats',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            icon: Icons.message_rounded,
            color: AppColors.primary,
            count: messages,
            label: 'Messages',
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final String label;

  const _StatBox({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
