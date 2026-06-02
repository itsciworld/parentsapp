import 'package:flutter/material.dart';

class SmsStateCard extends StatelessWidget {
  final int total;
  final int suspicious;
  final int unknown;

  const SmsStateCard({
    super.key,
    this.total = 0,
    this.suspicious = 0,
    this.unknown = 0,
  });

  Widget item(IconData icon, Color color, String count, String title) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),

          const SizedBox(height: 4),

          Text(
            count,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10),
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
        border: Border.all(width: .1, color: Colors.black),
      ),
      child: Row(
        children: [
          item(
            Icons.message_rounded,
            Colors.blue,
            "$total",
            "Total Messages",
          ),

          item(
            Icons.warning_amber_rounded,
            Colors.red,
            "$suspicious",
            "Suspicious",
          ),

          item(
            Icons.person_outline,
            Colors.deepPurple,
            "$unknown",
            "Unknown Contact",
          ),
        ],
      ),
    );
  }
}
