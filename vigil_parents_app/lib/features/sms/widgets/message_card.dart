import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/sms/models/sms_model.dart';

class MessageCard extends StatelessWidget {
  final SmsModel model;
  final double width;

  const MessageCard({super.key, required this.model, required this.width});

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar ──────────────────────────────────────────────
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: model.image.isNotEmpty
                ? NetworkImage(model.image)
                : null,
            child: model.image.isEmpty
                ? Text(
                    _initials(model.name),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // ── Content ─────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + time
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        model.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (model.time.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        model.time,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),

                if (model.phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    model.phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Body / media / voice
                if (model.isMedia && model.image.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
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
                      const Icon(Icons.play_arrow_rounded, size: 20),
                      Expanded(child: Slider(value: 0.3, onChanged: (_) {})),
                      const Text("0:12"),
                    ],
                  )
                else if (model.message.isNotEmpty)
                  Text(
                    model.message,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: AppColors.textPrimary,
                    ),
                  ),

                const SizedBox(height: 10),

                // Footer: unknown badge + sent/received chip at the end
                Row(
                  children: [
                    if (model.isUnknown)
                      _chip(
                        'Unknown Contact',
                        AppColors.alert,
                        AppColors.alert.withValues(alpha: 0.10),
                      ),
                    const Spacer(),
                    _chip(
                      model.isSent ? 'Sent' : 'Received',
                      model.isSent ? AppColors.primary : AppColors.blueIcon,
                      (model.isSent ? AppColors.primary : AppColors.blueIcon)
                          .withValues(alpha: 0.10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
