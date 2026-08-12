import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/app_usage/models/app_usage_model.dart';
import 'package:vigil_parents_app/features/app_usage/presentation/view/app_usage_detail_view.dart';
import 'package:vigil_parents_app/features/app_usage/presentation/view_model/app_usage_viewmodel.dart';
import 'package:vigil_parents_app/features/app_usage/presentation/widgets/app_icon_avatar.dart';

/// Home "Activity Overview" card — total screen time plus a mini animated bar
/// chart of the most-used apps, with an expand icon to the full detail view.
class ActivityOverviewCard extends ConsumerWidget {
  const ActivityOverviewCard({super.key});

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => const AppUsageDetailScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(appUsageViewModelProvider);
    final top = vm.top(5);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.darkCard, Color(0xFF0A1A3C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Header --------------------------------------------------
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Usage',
                      style: TextStyle(
                        color: AppColors.textOnDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      "Today's screen time",
                      style: TextStyle(
                        color: AppColors.textOnDarkMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              _ExpandButton(onTap: () => _openDetail(context)),
            ],
          ),
          const SizedBox(height: 16),
          _Body(vm: vm, top: top, onExpand: () => _openDetail(context)),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final AppUsageViewModel vm;
  final List<AppUsage> top;
  final VoidCallback onExpand;

  const _Body({required this.vm, required this.top, required this.onExpand});

  @override
  Widget build(BuildContext context) {
    if (vm.loading && top.isEmpty) {
      return Shimmer.fromColors(
        baseColor: Colors.white.withValues(alpha: 0.10),
        highlightColor: Colors.white.withValues(alpha: 0.22),
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }

    if (top.isEmpty) {
      return SizedBox(
        height: 96,
        child: Center(
          child: Text(
            vm.error ?? 'No app usage tracked yet',
            style: const TextStyle(
              color: AppColors.textOnDarkMuted,
              fontSize: 12.5,
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Total screen time + compact legend.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    vm.totalLabel,
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${vm.apps.length} apps',
                      style: const TextStyle(
                        color: AppColors.textOnDarkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _MiniLegend(apps: top, totalMinutes: vm.totalMinutes),
            ],
          ),
        ),
        const SizedBox(width: 14),
        // Usage-share donut of the most-used apps.
        SizedBox(
          width: 92,
          height: 92,
          child: _UsageDonut(apps: vm.apps, totalMinutes: vm.totalMinutes),
        ),
      ],
    );
  }
}

/// Compact usage-share donut for the home card. Shows the top apps as colored
/// slices with everything else grouped into a grey "Others" slice.
class _UsageDonut extends StatelessWidget {
  final List<AppUsage> apps;
  final int totalMinutes;

  const _UsageDonut({required this.apps, required this.totalMinutes});

  static const int _maxSlices = 5;
  static const Color _othersColor = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final shown = apps.length <= _maxSlices ? apps.length : _maxSlices;
    final sections = <PieChartSectionData>[];

    for (var i = 0; i < shown; i++) {
      sections.add(
        PieChartSectionData(
          value: apps[i].usageMinutes.toDouble(),
          color: AppIconAvatar.colorFor(apps[i].appName, apps[i].packageName),
          radius: 16,
          showTitle: false,
        ),
      );
    }
    if (apps.length > _maxSlices) {
      final others = apps
          .sublist(_maxSlices)
          .fold<int>(0, (sum, a) => sum + a.usageMinutes);
      if (others > 0) {
        sections.add(
          PieChartSectionData(
            value: others.toDouble(),
            color: _othersColor,
            radius: 16,
            showTitle: false,
          ),
        );
      }
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sections: sections,
            sectionsSpace: 2,
            centerSpaceRadius: 24,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(enabled: false),
          ),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
        ),
        // Center icon inside the ring.
        const Icon(
          Icons.phone_iphone_rounded,
          size: 20,
          color: AppColors.textOnDarkMuted,
        ),
      ],
    );
  }
}

/// A small color-dot + name + percent legend for the most-used apps.
class _MiniLegend extends StatelessWidget {
  final List<AppUsage> apps;
  final int totalMinutes;

  const _MiniLegend({required this.apps, required this.totalMinutes});

  @override
  Widget build(BuildContext context) {
    final rows = apps.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final app in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppIconAvatar.colorFor(app.appName, app.packageName),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    app.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  totalMinutes <= 0
                      ? '0%'
                      : '${(app.usageMinutes / totalMinutes * 100).round()}%',
                  style: const TextStyle(
                    color: AppColors.textOnDarkMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ExpandButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExpandButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.open_in_full_rounded,
            size: 17,
            color: AppColors.textOnDark,
          ),
        ),
      ),
    );
  }
}
