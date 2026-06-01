import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';
import 'package:vigil_parents_app/features/home/presentation/view_model/home_viewmodel.dart';
import 'package:vigil_parents_app/features/home/widgets/activity_summery.dart';
import 'package:vigil_parents_app/features/home/widgets/ai_foundation.dart';
import 'package:vigil_parents_app/features/home/widgets/child_card.dart';
import 'package:vigil_parents_app/features/home/widgets/feature_grid.dart';
import 'package:vigil_parents_app/features/home/widgets/home_aapbar.dart';
import 'package:vigil_parents_app/features/profile/presentation/view_model/profile_viewmodel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  /// Called when the parent chip is tapped — wired to open the Profile tab.
  final VoidCallback? onProfileTap;

  const HomeScreen({super.key, this.onProfileTap});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final HomeViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = HomeViewModel();
    _vm.init();
    // Load the parent profile so the header shows the real name.
    Future.microtask(() => ref.read(profileViewModelProvider).loadProfile());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  /// Builds the chip profile from the API, falling back to the dashboard's
  /// parent while the profile request is still in flight.
  ParentProfile _parentChip(ParentProfile fallback) {
    final name = ref.watch(profileViewModelProvider).profile?.name;
    if (name == null || name.trim().isEmpty) return fallback;
    return ParentProfile(name: name, initials: _initialsFor(name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          if (_vm.isLoading) return const _LoadingView();
          if (_vm.hasError) {
            return _ErrorView(
              message: _vm.errorMessage ?? 'Something went wrong',
              onRetry: _vm.refresh,
            );
          }
          return _LoadedView(
            vm: _vm,
            data: _vm.data!,
            parent: _parentChip(_vm.data!.parent),
            onParentTap: widget.onProfileTap,
          );
        },
      ),
    );
  }
}

String _initialsFor(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

/// ----------------------------------------------------------------------------
/// Loaded state
/// ----------------------------------------------------------------------------
class _LoadedView extends StatelessWidget {
  final HomeViewModel vm;
  final HomeDashboardData data;
  final ParentProfile parent;
  final VoidCallback? onParentTap;

  const _LoadedView({
    required this.vm,
    required this.data,
    required this.parent,
    required this.onParentTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: RefreshIndicator(
        onRefresh: vm.refresh,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Dark gradient header --------------------------------
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.headerTop, AppColors.headerBottom],
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 24),
                child: Column(
                  children: [
                    HomeAapbar(
                      parent: parent,
                      notificationCount: data.notificationCount,
                      onMenuTap: () {},
                      onNotificationsTap: vm.onNotificationsTapped,
                      onParentTap: onParentTap,
                    ),
                    const SizedBox(height: 18),
                    ChildHeaderCard(
                      child: data.child,
                      indicators: data.statusIndicators,
                    ),
                  ],
                ),
              ),

              // ---- White body ------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      title: 'Monitoring Tools',
                      subtitle: 'Tap a tool to view activity',
                    ),
                    const SizedBox(height: 14),
                    FeatureGrid(
                      features: data.features,
                      onTap: (tile) => vm.onFeatureTapped(context, tile),
                    ),
                    const SizedBox(height: 26),
                    const _SectionTitle(title: 'Activity Overview'),
                    const SizedBox(height: 14),
                    ActivitySummaryCard(
                      activity: data.activity,
                      onViewAllAlerts: vm.onViewAllAlerts,
                    ),
                    const SizedBox(height: 26),
                    const _SectionTitle(title: 'Our Initiative'),
                    const SizedBox(height: 14),
                    FoundationCard(
                      info: data.foundation,
                      onKnowMore: vm.onKnowMoreFoundation,
                    ),
                    SizedBox(height: bottomPadding + 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A consistent section heading: a bold title with an optional muted
/// subtitle below it.
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// Loading state
/// ----------------------------------------------------------------------------
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              // 🔹 Header skeleton
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.white),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _box(width: 40, height: 40, radius: 20),
                        const SizedBox(width: 12),
                        Expanded(child: _box(height: 16)),
                        const SizedBox(width: 12),
                        _box(width: 30, height: 30, radius: 8),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _box(height: 90, radius: 16),
                  ],
                ),
              ),

              // 🔹 Body skeleton
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(width: 160, height: 18, radius: 6),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 6,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 15,
                            crossAxisSpacing: 15,
                          ),
                      itemBuilder: (_, _) => _box(radius: 14),
                    ),
                    const SizedBox(height: 24),
                    _box(width: 140, height: 18, radius: 6),
                    const SizedBox(height: 16),
                    _box(height: 110, radius: 20),
                    const SizedBox(height: 24),
                    _box(width: 120, height: 18, radius: 6),
                    const SizedBox(height: 16),
                    _box(height: 220, radius: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box({
    double width = double.infinity,
    double height = 16,
    double radius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Error state
/// ----------------------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Unable to load dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
