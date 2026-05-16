import 'package:flutter/material.dart';

class SmsHeader extends StatelessWidget {
  const SmsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              child: const Icon(Icons.arrow_back_ios_new),
            ),

            const Spacer(),

            Column(
              children: [
                Text(
                  "VIGIL",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade900,
                  ),
                ),

                const Text(
                  "Watch Smart. Protect Better",
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),

            const Spacer(),

            const Icon(Icons.refresh),
          ],
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.blue.shade400,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sms, color: Colors.white, size: 32),
            ),

            const SizedBox(width: 16),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    " Messages",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),

                  SizedBox(height: 4),

                  Text(
                    "View and monitor WhatsApp conversations",
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
