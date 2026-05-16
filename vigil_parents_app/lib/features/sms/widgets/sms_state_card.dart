import 'package:flutter/material.dart';

class SmsStateCard extends StatelessWidget {
  const SmsStateCard({super.key});

  Widget item(IconData icon, Color color, String count, String title) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 25),

          const SizedBox(height: 8),

          Text(
            count,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          item(Icons.message_rounded, Colors.blue, "128", "Total Messages"),

          item(Icons.warning_amber_rounded, Colors.red, "3", "Suspicious"),

          item(Icons.person_outline, Colors.deepPurple, "1", "Unknown Contact"),
        ],
      ),
    );
  }
}
