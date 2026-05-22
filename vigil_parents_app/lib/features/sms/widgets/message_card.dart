import 'package:flutter/material.dart';
import 'package:vigil_parents_app/features/sms/models/sms_model.dart';

class MessageCard extends StatelessWidget {
  final SmsModel model;
  final double width;

  const MessageCard({super.key, required this.model, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: width * 0.07,
            backgroundImage: NetworkImage(model.image),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  model.phone,
                  style: TextStyle(color: Colors.grey.shade600),
                ),

                const SizedBox(height: 10),

                if (model.isMedia)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      model.image,
                      height: 120,
                      width: 180,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (model.isVoice)
                  Row(
                    children: [
                      const Icon(Icons.play_arrow),

                      Expanded(child: Slider(value: 0.3, onChanged: (_) {})),

                      const Text("0:12"),
                    ],
                  )
                else
                  Text(model.message),

                if (model.isUnknown)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Text(
                        "Unknown Contact",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Column(
            children: [
              Text(model.time),

              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: model.isSent
                      ? Colors.green.withValues(alpha: .1)
                      : Colors.blue.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Text(
                  model.isSent ? "Sent" : "Received",
                  style: TextStyle(
                    color: model.isSent ? Colors.green : Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
