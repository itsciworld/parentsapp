import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';

/// Summary strip above the SMS thread list: number of conversations (threads)
/// and the total messages across them.
class SmsStateCard extends StatelessWidget {
  final int threads;
  final int messages;

  const SmsStateCard({super.key, this.threads = 0, this.messages = 0});

  Widget _item(IconData icon, Color color, String count, String title) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(width: .4, color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          _item(
            Icons.forum_rounded,
            AppColors.blueIcon,
            '$threads',
            'Conversations',
          ),
          Container(width: .5, height: 34, color: AppColors.cardBorder),
          _item(
            Icons.message_rounded,
            AppColors.primary,
            '$messages',
            'Total Messages',
          ),
        ],
      ),
    );
  }
}
