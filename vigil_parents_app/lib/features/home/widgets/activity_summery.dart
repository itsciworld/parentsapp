import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';
// ... your ActivitySummaryCard class code ...

/// THIS MUST BE IN THE SAME FILE AT THE TOP LEVEL
class _SparklinePainter extends CustomPainter {
  final List<double> points;
  _SparklinePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final stepX = size.width / (points.length - 1);
    final path = Path();
    final coords = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final x = stepX * i;
      // Normalizing the points to fit the height of the container
      final y = size.height - (points[i].clamp(0, 1) * size.height);
      coords.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = AppColors.primary;
    for (final c in coords) {
      canvas.drawCircle(c, 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.points != points;
}

/// The dark "Today's Activity Summary" panel: sparkline on the left, then
/// Screen Time and Alerts metric columns separated by vertical dividers.
class ActivitySummaryCard extends StatelessWidget {
  final ActivitySummary activity;
  final VoidCallback onViewAllAlerts;

  const ActivitySummaryCard({
    super.key,
    required this.activity,
    required this.onViewAllAlerts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12), // Slightly more padding for balance
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title + sparkline ----------------------------------------------
            Expanded(
              flex:
                  5, // Increased flex to prevent title wrapping too aggressively
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Today's Activity\nSummary",
                      style: TextStyle(
                        color: AppColors.textOnDark,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 24,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _SparklinePainter(points: activity.sparkline),
                    ),
                  ),
                ],
              ),
            ),
            _divider(),
            // Screen time ----------------------------------------------------
            Expanded(
              flex: 4,
              child: _Metric(
                icon: Icons.access_time_rounded,
                iconColor: AppColors.primary,
                label: 'Screen Time',
                value: activity.screenTime,
                footer: _DeltaFooter(percent: activity.screenTimeDeltaPercent),
              ),
            ),
            _divider(),
            // Alerts ---------------------------------------------------------
            Expanded(
              flex: 4,
              child: _Metric(
                icon: Icons.error_rounded,
                iconColor: AppColors.alert,
                label: 'Alerts',
                value: '${activity.alertCount}',
                footer: InkWell(
                  // Better touch feedback than GestureDetector
                  onTap: onViewAllAlerts,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View all',
                          style: TextStyle(
                            color: AppColors.textOnDarkMuted,
                            fontSize: 10,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textOnDarkMuted,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: Colors.white.withValues(alpha: 0.1),
  );
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget footer;

  const _Metric({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 13),
            const SizedBox(width: 4),
            Expanded(
              // Use Expanded here to prevent label from pushing the icon
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.textOnDarkMuted,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          // Ensures large time strings (e.g. "12h 45m") don't overflow
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.textOnDark,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),
        footer,
      ],
    );
  }
}

class _DeltaFooter extends StatelessWidget {
  final double percent;
  const _DeltaFooter({required this.percent});

  @override
  Widget build(BuildContext context) {
    final isUp = percent >= 0;
    return FittedBox(
      // Shrinks the "from yesterday" text on tiny screens
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: AppColors.primary,
            size: 10,
          ),
          const SizedBox(width: 2),
          Text(
            '${percent.abs().toStringAsFixed(0)}% prev', // Shortened text for better fit
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
