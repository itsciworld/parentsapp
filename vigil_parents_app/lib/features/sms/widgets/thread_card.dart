import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/sms/models/sms_thread_model.dart';

/// A single conversation row in the SMS thread list: contact/number, last
/// message preview, time, and a count badge of messages in the thread.
class ThreadCard extends StatelessWidget {
  final SmsThread thread;

  /// Unread messages in this thread — shown as a badge, hidden when 0.
  final int unread;
  final VoidCallback onTap;

  const ThreadCard({
    super.key,
    required this.thread,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final last = thread.lastMessage;
    final preview = thread.preview.trim();
    final isSentLast = last?.isSent ?? false;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  _initials(thread.address),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.address.isEmpty
                                ? 'Unknown'
                                : thread.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (thread.lastMessageAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatRelative(thread.lastMessageAt!),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (isSentLast)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.reply_rounded,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            preview.isEmpty ? 'No messages' : preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Unread badge — count of new messages; clears once opened.
              if (unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return '#';
    // Numbers: use the last two digits; otherwise the first letter.
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 2) return digits.substring(digits.length - 2);
    return trimmed.characters.first.toUpperCase();
  }

  static String _formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month]}';
  }
}
