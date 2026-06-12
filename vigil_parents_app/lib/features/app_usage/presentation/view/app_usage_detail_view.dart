import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/components/app_bottom_nav.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/app_usage/models/app_usage_model.dart';
import 'package:vigil_parents_app/features/app_usage/presentation/view_model/app_usage_viewmodel.dart';
import 'package:vigil_parents_app/features/app_usage/presentation/widgets/app_icon_avatar.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';

/// Full-screen app-usage breakdown: total screen time, an animated bar chart of
/// the most-used apps, and a list (top 5, expandable to all). The child picker
/// matches the SMS/Location screens.
class AppUsageDetailScreen extends ConsumerStatefulWidget {
  const AppUsageDetailScreen({super.key});

  @override
  ConsumerState<AppUsageDetailScreen> createState() =>
      _AppUsageDetailScreenState();
}

class _AppUsageDetailScreenState extends ConsumerState<AppUsageDetailScreen> {
  static const int _previewCount = 5;
  bool _showAll = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Always fetch fresh stats on open.
    Future.microtask(() async {
      await ref.read(selectedChildProvider).load();
      final vm = ref.read(appUsageViewModelProvider);
      final id = ref.read(selectedChildProvider).selectedId;
      if (id == null) return;
      if (vm.childId == id && vm.apps.isNotEmpty) {
        vm.refresh();
      } else {
        vm.load(id);
      }
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(appUsageViewModelProvider).refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _onChildSelected(String childId) {
    setState(() => _showAll = false);
    ref.read(appUsageViewModelProvider).load(childId);
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(appUsageViewModelProvider);
    final childName = ref.watch(selectedChildProvider).selected?.name;
    final apps = vm.apps;
    final visible = _showAll ? apps : vm.top(_previewCount);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // VIGIL logo header (same as SMS / other views).
            const AppHeader(),
            _TitleBar(onChildSelected: _onChildSelected),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => ref.read(appUsageViewModelProvider).refresh(),
                child: _buildContent(context, vm, apps, visible, childName),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppUsageViewModel vm,
    List<AppUsage> apps,
    List<AppUsage> visible,
    String? childName,
  ) {
    if (vm.loading && apps.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (apps.isEmpty) {
      return _EmptyView(error: vm.error);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _Reveal(delayMs: 0, child: _TotalHero(vm: vm, childName: childName)),
        const SizedBox(height: 18),
        _Reveal(
          delayMs: 90,
          child: _PieCard(apps: vm.apps, totalMinutes: vm.totalMinutes),
        ),
        const SizedBox(height: 22),
        _Reveal(
          delayMs: 160,
          child: _AppsHeader(
            count: apps.length,
            showAll: _showAll,
            canToggle: apps.length > _previewCount,
            onToggle: () => setState(() => _showAll = !_showAll),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < visible.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AppRow(
              index: i,
              app: visible[i],
              rank: i + 1,
              maxMinutes: vm.maxMinutes,
              totalMinutes: vm.totalMinutes,
            ),
          ),
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// Title + shared child dropdown, shown under the VIGIL logo header.
/// ----------------------------------------------------------------------------
class _TitleBar extends StatelessWidget {
  final ValueChanged<String> onChildSelected;

  const _TitleBar({required this.onChildSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 14, 10),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Usage',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Screen time by app',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChildSelectorDropdown(onChanged: onChildSelected),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Total screen-time hero
/// ----------------------------------------------------------------------------
class _TotalHero extends StatelessWidget {
  final AppUsageViewModel vm;
  final String? childName;

  const _TotalHero({required this.vm, required this.childName});

  @override
  Widget build(BuildContext context) {
    final most = vm.apps.isNotEmpty ? vm.apps.first : null;
    final name = (childName == null || childName!.trim().isEmpty)
        ? 'Total screen time'
        : "${childName!.trim()}'s screen time";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.darkCard, Color(0xFF0A1A3C)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textOnDarkMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  vm.totalLabel,
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Stat(value: '${vm.apps.length}', label: 'apps'),
                    if (most != null) ...[
                      const SizedBox(width: 18),
                      Flexible(
                        child: _Stat(
                          value: most.appName,
                          label: 'most used',
                          truncate: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Decorative ring with a clock.
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.hourglass_bottom_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool truncate;

  const _Stat({
    required this.value,
    required this.label,
    this.truncate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: truncate ? TextOverflow.ellipsis : TextOverflow.clip,
          style: const TextStyle(
            color: AppColors.textOnDark,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textOnDarkMuted,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// Animated donut chart — each app's share of total screen time. The top apps
/// are shown individually; anything beyond is aggregated into "Others". Tap a
/// slice to enlarge it.
/// ----------------------------------------------------------------------------
class _PieSlice {
  final String label;
  final int minutes;
  final Color color;
  const _PieSlice(this.label, this.minutes, this.color);
}

class _PieCard extends StatefulWidget {
  final List<AppUsage> apps;
  final int totalMinutes;

  const _PieCard({required this.apps, required this.totalMinutes});

  @override
  State<_PieCard> createState() => _PieCardState();
}

class _PieCardState extends State<_PieCard> {
  int _touched = -1;

  static const int _maxSlices = 5;
  static const Color _othersColor = Color(0xFF94A3B8);

  List<_PieSlice> _buildSlices() {
    final apps = widget.apps;
    final slices = <_PieSlice>[];
    final shown = apps.length <= _maxSlices ? apps.length : _maxSlices;
    for (var i = 0; i < shown; i++) {
      slices.add(
        _PieSlice(
          apps[i].appName,
          apps[i].usageMinutes,
          AppIconAvatar.colorFor(apps[i].appName, apps[i].packageName),
        ),
      );
    }
    if (apps.length > _maxSlices) {
      final othersMinutes = apps
          .sublist(_maxSlices)
          .fold<int>(0, (sum, a) => sum + a.usageMinutes);
      if (othersMinutes > 0) {
        slices.add(_PieSlice('Others', othersMinutes, _othersColor));
      }
    }
    return slices;
  }

  @override
  Widget build(BuildContext context) {
    final slices = _buildSlices();
    final total = widget.totalMinutes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.purpleIcon.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 14),
            child: Text(
              'Usage share',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Row(
            children: [
              // Donut + center total.
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 42,
                        startDegreeOffset: -90,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  response?.touchedSection == null) {
                                _touched = -1;
                                return;
                              }
                              _touched = response!
                                  .touchedSection!
                                  .touchedSectionIndex;
                            });
                          },
                        ),
                        sections: [
                          for (var i = 0; i < slices.length; i++)
                            _section(slices[i], i, total),
                        ],
                      ),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppUsage.formatMinutes(total),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'total',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Legend.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < slices.length; i++)
                      _LegendRow(
                        slice: slices[i],
                        percent: total <= 0
                            ? 0
                            : (slices[i].minutes / total * 100).round(),
                        highlighted: _touched == i,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _section(_PieSlice slice, int index, int total) {
    final isTouched = index == _touched;
    final percent = total <= 0 ? 0 : (slice.minutes / total * 100).round();
    return PieChartSectionData(
      value: slice.minutes.toDouble(),
      color: slice.color,
      radius: isTouched ? 32 : 26,
      // Only label slices that are wide enough to read.
      showTitle: percent >= 8,
      title: '$percent%',
      titleStyle: TextStyle(
        fontSize: isTouched ? 13 : 11,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
      ),
      titlePositionPercentageOffset: 0.58,
    );
  }
}

class _LegendRow extends StatelessWidget {
  final _PieSlice slice;
  final int percent;
  final bool highlighted;

  const _LegendRow({
    required this.slice,
    required this.percent,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: slice.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                color: highlighted
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$percent%',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// "Apps" section header with the See all / Show less toggle.
/// ----------------------------------------------------------------------------
class _AppsHeader extends StatelessWidget {
  final int count;
  final bool showAll;
  final bool canToggle;
  final VoidCallback onToggle;

  const _AppsHeader({
    required this.count,
    required this.showAll,
    required this.canToggle,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.blueIcon],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const Text(
          'All Apps',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        if (canToggle)
          Material(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      showAll ? 'Show less' : 'See all',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      showAll
                          ? Icons.expand_less_rounded
                          : Icons.grid_view_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// A single app row with an animated usage bar.
/// ----------------------------------------------------------------------------
class _AppRow extends StatelessWidget {
  final int index;
  final AppUsage app;
  final int rank;
  final int maxMinutes;
  final int totalMinutes;

  const _AppRow({
    required this.index,
    required this.app,
    required this.rank,
    required this.maxMinutes,
    required this.totalMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxMinutes <= 0 ? 0.0 : app.usageMinutes / maxMinutes;
    final share = totalMinutes <= 0
        ? 0
        : (app.usageMinutes / totalMinutes * 100).round();
    final color = AppIconAvatar.colorFor(app.appName, app.packageName);

    return _Reveal(
      delayMs: 40 * index,
      slideX: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            AppIconAvatar(
              appName: app.appName,
              packageName: app.packageName,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          app.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        app.usageLabel,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  // Animated proportional bar.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 7,
                          backgroundColor: AppColors.scaffold,
                          valueColor: AlwaysStoppedAnimation(color),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$share% of total screen time',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String? error;
  const _EmptyView({this.error});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(
          error != null ? Icons.cloud_off_rounded : Icons.apps_rounded,
          size: 52,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            error ?? 'No app usage tracked yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Fade + slide entrance wrapper.
class _Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final bool slideX;

  const _Reveal({required this.child, this.delayMs = 0, this.slideX = false});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: widget.slideX
                ? Offset((1 - t) * 26, 0)
                : Offset(0, (1 - t) * 24),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
