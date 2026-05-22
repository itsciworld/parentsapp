import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';
import 'package:vigil_parents_app/features/home/widgets/omman_widgets.dart';

/// The soft gradient "AI Insight" banner with a robot mascot.
///
/// REPLACE-LATER: the robot is an [Icon] placeholder. Swap `_RobotMascot` with
/// your illustration asset, e.g. Image.asset('assets/images/ai_robot.png').
class AiInsightCard extends StatelessWidget {
  final AiInsight insight;
  final VoidCallback onViewInsight;

  const AiInsightCard({
    super.key,
    required this.insight,
    required this.onViewInsight,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [AppColors.aiCardStart, AppColors.aiCardEnd],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // AI chip icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.purpleIcon,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.memory_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          // Text + button
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(insight.title, style: TextStyle()),
                    const SizedBox(width: 6),
                    if (insight.isNew)
                      const StatusPill(
                        label: 'New',
                        color: Color(0xFFE7DAFA),
                        textColor: AppColors.purpleIcon,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(insight.message, style: TextStyle(height: 1.35)),
                const SizedBox(height: 20),
                Material(
                  color: AppColors.purpleIcon,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: onViewInsight,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      child: Text(
                        'View Insight',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textOnDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const _RobotMascot(),
        ],
      ),
    );
  }
}

/// Placeholder robot mascot. REPLACE-LATER with an illustration asset.
class _RobotMascot extends StatelessWidget {
  const _RobotMascot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.purpleIcon.withValues(alpha: 0.3)),
      ),
      child: const Icon(
        Icons.smart_toy_rounded,
        color: AppColors.purpleIcon,
        size: 30,
      ),
    );
  }
}

/// The CSR / foundation footer card.
///
/// REPLACE-LATER: `_FoundationLogo` is an icon+text placeholder. Swap it with
/// the real foundation logo asset.
class FoundationCard extends StatelessWidget {
  final FoundationInfo info;
  final VoidCallback onKnowMore;

  const FoundationCard({
    super.key,
    required this.info,
    required this.onKnowMore,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      color: AppColors.primaryLight,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔹 TOP HEADER
          Row(
            children: [
              const _FoundationLogo(),
              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  info.tagline,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          /// 🔹 DESCRIPTION
          Text(
            info.description,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 16),

          /// 🔹 STATS (MODERN STYLE)
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  icon: Icons.groups_rounded,
                  value: info.childrenImpacted,
                  label: 'Children',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBox(
                  icon: Icons.school_rounded,
                  value: info.awarenessSessions,
                  label: 'Sessions',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBox(
                  icon: Icons.favorite_rounded,
                  value: info.communitySupporters,
                  label: 'Supporters',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// 🔹 CTA BUTTON (FULL WIDTH 🔥)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onKnowMore,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Know More",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _FoundationLogo extends StatelessWidget {
  const _FoundationLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.volunteer_activism_rounded,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 60,
          child: Text(
            'MITRA HELP\nFOUNDATION',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
              fontSize: 8,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
