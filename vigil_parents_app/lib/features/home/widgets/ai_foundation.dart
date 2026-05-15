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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FoundationLogo(),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.tagline,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.description,
                      style: TextStyle(color: Colors.grey, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onKnowMore,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Know More',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.north_east_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _FoundationStat(
                  icon: Icons.groups_rounded,
                  value: info.childrenImpacted,
                  label: 'Children Impacted',
                ),
              ),
              Expanded(
                child: _FoundationStat(
                  icon: Icons.cast_for_education_rounded,
                  value: info.awarenessSessions,
                  label: 'Awareness Sessions',
                ),
              ),
              Expanded(
                child: _FoundationStat(
                  icon: Icons.diversity_3_rounded,
                  value: info.communitySupporters,
                  label: 'Community Supporters',
                ),
              ),
            ],
          ),
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

class _FoundationStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _FoundationStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: AppColors.primaryDark, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9)),
      ],
    );
  }
}
