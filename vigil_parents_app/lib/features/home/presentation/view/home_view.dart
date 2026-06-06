import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/no_child_linked_view.dart';
import 'package:vigil_parents_app/features/device_info/models/device_info_model.dart';
import 'package:vigil_parents_app/features/device_info/presentation/view_model/device_info_viewmodel.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';
import 'package:vigil_parents_app/features/home/presentation/view_model/feature_badges_viewmodel.dart';
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
    Future.microtask(() async {
      ref.read(profileViewModelProvider).loadProfile();
      // Load the children list, then the device info + badges for the selected.
      await ref.read(selectedChildProvider).load();
      final id = ref.read(selectedChildProvider).selectedId;
      if (id != null) ref.read(deviceInfoViewModelProvider).load(id);
      ref.read(featureBadgesProvider).load();
    });
  }

  /// Refreshes the device info + badges for the newly-selected child. The
  /// dropdown itself persists the selection.
  void _onChildSelected(String childId) {
    ref.read(deviceInfoViewModelProvider).load(childId);
    ref.read(featureBadgesProvider).load();
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
            onChildSelected: _onChildSelected,
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
class _LoadedView extends ConsumerWidget {
  final HomeViewModel vm;
  final HomeDashboardData data;
  final ParentProfile parent;
  final VoidCallback? onParentTap;
  final ValueChanged<String> onChildSelected;

  const _LoadedView({
    required this.vm,
    required this.data,
    required this.parent,
    required this.onParentTap,
    required this.onChildSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final selectedChild = ref.watch(selectedChildProvider);
    final deviceInfoVm = ref.watch(deviceInfoViewModelProvider);
    final badges = ref.watch(featureBadgesProvider);

    // Override the static tile badges with the dynamic "unseen" counts.
    final features = [
      for (final t in data.features)
        t.withBadge(
          badges.unseenFor(t.id) > 0 ? badges.unseenFor(t.id) : null,
        ),
    ];

    // Merge the selected child + live device info over the dummy fallback so
    // the header reflects the real, currently-selected child.
    final childProfile = _buildChildProfile(
      fallback: data.child,
      selectedName: selectedChild.selected?.name,
      info: deviceInfoVm.info,
    );

    // No child registered/linked to this account yet (only after the first
    // fetch has completed, so the header doesn't flash this state on startup).
    final noChild = selectedChild.initialized && selectedChild.children.isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            vm.refresh(),
            ref.read(featureBadgesProvider).load(),
          ]);
        },
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
                    if (noChild)
                      NoChildLinkedView(
                        dark: true,
                        refreshing: selectedChild.loading,
                        onRefresh: () =>
                            ref.read(selectedChildProvider).load(force: true),
                      )
                    else
                      ChildHeaderCard(
                        child: childProfile,
                        indicators: data.statusIndicators,
                        trailing: ChildSelectorDropdown(
                          onChanged: onChildSelected,
                          dark: true,
                          showLabel: false,
                        ),
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
                      features: features,
                      onTap: (tile) {
                        // Clear the badge immediately, navigate, then refresh
                        // badges on return so new items reappear.
                        ref.read(featureBadgesProvider).markSeenForTile(tile.id);
                        vm.onFeatureTapped(context, tile).then(
                          (_) => ref.read(featureBadgesProvider).load(),
                        );
                      },
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

  /// Builds the header [ChildProfile] from the selected child + its live
  /// device info, falling back to the dummy dashboard values when those
  /// aren't loaded yet.
  ChildProfile _buildChildProfile({
    required ChildProfile fallback,
    required String? selectedName,
    required DeviceInfoResponse? info,
  }) {
    final device = info?.deviceInfo;

    String firstNonEmpty(List<String?> values, String fallbackValue) {
      for (final v in values) {
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
      return fallbackValue;
    }

    return ChildProfile(
      name: firstNonEmpty([selectedName, info?.name], fallback.name),
      avatarUrl: fallback.avatarUrl,
      isOnline: info?.isOnline ?? fallback.isOnline,
      deviceModel: firstNonEmpty([
        device?.model,
        info?.deviceName,
      ], fallback.deviceModel),
      osVersion: firstNonEmpty([device?.osVersion], fallback.osVersion),
      lastSync: _formatLastSeen(info?.lastSeen) ?? fallback.lastSync,
    );
  }

  /// Formats an ISO timestamp into a short, human "last sync" label.
  String? _formatLastSeen(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return null;

    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} day(s) ago';

    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
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
