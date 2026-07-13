import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/app_usage/presentation/widgets/activity_overview_card.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/no_child_linked_view.dart';
import 'package:vigil_parents_app/features/device_info/models/device_info_model.dart';
import 'package:vigil_parents_app/features/device_info/presentation/view_model/device_info_viewmodel.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';
import 'package:vigil_parents_app/features/home/presentation/view_model/feature_badges_viewmodel.dart';
import 'package:vigil_parents_app/features/home/presentation/view_model/home_viewmodel.dart';
import 'package:vigil_parents_app/features/app_usage/presentation/view_model/app_usage_viewmodel.dart';
import 'package:vigil_parents_app/features/home/widgets/ai_foundation.dart';
import 'package:vigil_parents_app/features/home/widgets/feature_grid.dart';
import 'package:vigil_parents_app/features/live_status/models/live_status_model.dart';
import 'package:vigil_parents_app/features/live_status/presentation/view_model/live_status_viewmodel.dart';
import 'package:vigil_parents_app/features/location/presentation/view_model/location_viewmodel.dart';
import 'package:vigil_parents_app/features/location/presentation/widgets/home_location_card.dart';
import 'package:vigil_parents_app/features/social_apps/presentation/view_model/social_screen_viewmodel.dart';
import 'package:vigil_parents_app/features/social_apps/presentation/widgets/social_apps_card.dart';
import 'package:vigil_parents_app/features/profile/presentation/view_model/profile_viewmodel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  /// Called when the parent chip is tapped — wired to open the Profile tab.
  final VoidCallback? onProfileTap;

  const HomeScreen({super.key, this.onProfileTap});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  late final HomeViewModel _vm;
  Timer? _locationTimer;
  LiveStatusViewModel? _liveStatusVm; // Save reference for dispose

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vm = HomeViewModel();
    _vm.init();
    Future.microtask(() async {
      if (!mounted) return;
      ref.read(profileViewModelProvider).loadProfile();
      await ref.read(selectedChildProvider).load();
      // The widget may have been unmounted while the child list loaded.
      if (!mounted) return;
      final id = ref.read(selectedChildProvider).selectedId;
      if (id != null) {
        ref.read(deviceInfoViewModelProvider).load(id);
        // Begin live battery/connectivity polling for the selected child.
        _liveStatusVm = ref.read(liveStatusViewModelProvider);
        _liveStatusVm!.startPolling(id);
        ref.read(locationViewModelProvider).load(id);
        ref.read(appUsageViewModelProvider).load(id);
        ref.read(socialScreenViewModelProvider).load(id);
      }
      ref.read(featureBadgesProvider).load();
    });

    // Keep the home map's "latest location" fresh while the screen is visible.
    _locationTimer = Timer.periodic(const Duration(seconds: 40), (_) {
      ref.read(locationViewModelProvider).refresh();
    });
  }

  void _onChildSelected(String childId) {
    ref.read(deviceInfoViewModelProvider).load(childId);
    ref.read(liveStatusViewModelProvider).startPolling(childId);
    ref.read(locationViewModelProvider).load(childId);
    ref.read(appUsageViewModelProvider).load(childId);
    ref.read(socialScreenViewModelProvider).load(childId);
    ref.read(featureBadgesProvider).load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause foreground polling when the app isn't visible — the background
    // service keeps the status fresh while we're away. Resume on return.
    final vm = ref.read(liveStatusViewModelProvider);
    if (state == AppLifecycleState.resumed) {
      final id = ref.read(selectedChildProvider).selectedId;
      if (id != null) vm.startPolling(id);

      ref.read(locationViewModelProvider).refresh();
      ref.read(appUsageViewModelProvider).refresh();
    } else {
      vm.stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    // Use saved reference instead of ref.read() during dispose
    _liveStatusVm?.stopPolling();
    _vm.dispose();
    super.dispose();
  }

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
/// Loaded state — clean light layout with staggered entrance animation.
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
    final liveStatusVm = ref.watch(liveStatusViewModelProvider);
    final badges = ref.watch(featureBadgesProvider);

    final features = [
      for (final t in data.features)
        t.withBadge(badges.unseenFor(t.id) > 0 ? badges.unseenFor(t.id) : null),
    ];

    final liveStatus = liveStatusVm.status;

    final childProfile = _buildChildProfile(
      fallback: data.child,
      selectedName: selectedChild.selected?.name,
      info: deviceInfoVm.info,
      live: liveStatus,
      lastSyncAt: liveStatusVm.lastSyncAt,
    );

    final noChild = selectedChild.initialized && selectedChild.children.isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Stack(
        children: [
          const _HeaderBackdrop(),
          RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                vm.refresh(),
                ref.read(liveStatusViewModelProvider).refresh(),
                ref.read(locationViewModelProvider).refresh(),
                ref.read(appUsageViewModelProvider).refresh(),
                ref.read(socialScreenViewModelProvider).refresh(),
                ref.read(featureBadgesProvider).load(),
              ]);
            },
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---- Greeting bar -------------------------------------
                    _Reveal(
                      delayMs: 0,
                      child: _TopBar(
                        parent: parent,
                        notificationCount: data.notificationCount,
                        onParentTap: onParentTap,
                        onNotificationsTap: () =>
                            vm.onNotificationsTapped(context),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ---- Child hero card ----------------------------------
                    _Reveal(
                      delayMs: 90,
                      child: noChild
                          ? NoChildLinkedView(
                              refreshing: selectedChild.loading,
                              onRefresh: () => ref
                                  .read(selectedChildProvider)
                                  .load(force: true),
                            )
                          : _ChildHeroCard(
                              child: childProfile,
                              battery: liveStatus?.battery,
                              connectivity: liveStatus?.connectivity,
                              dropdown: ChildSelectorDropdown(
                                onChanged: onChildSelected,
                                showLabel: false,
                              ),
                            ),
                    ),
                    const SizedBox(height: 26),

                    // ---- Monitoring tools ---------------------------------
                    _Reveal(
                      delayMs: 170,
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
                              ref
                                  .read(featureBadgesProvider)
                                  .markSeenForTile(tile.id);
                              vm
                                  .onFeatureTapped(context, tile)
                                  .then(
                                    (_) =>
                                        ref.read(featureBadgesProvider).load(),
                                  );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),

                    // ---- Social apps --------------------------------------
                    _Reveal(
                      delayMs: 190,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _SectionTitle(
                            title: 'Social Apps',
                            subtitle: 'Tap to view captured chat messages',
                          ),
                          SizedBox(height: 14),
                          SocialAppsCard(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),

                    // ---- Live location ------------------------------------
                    _Reveal(
                      delayMs: 205,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _SectionTitle(
                            title: 'Live Location',
                            subtitle: 'Tap the map for full history',
                          ),
                          SizedBox(height: 14),
                          HomeLocationCard(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),

                    // ---- App usage ----------------------------------------
                    _Reveal(
                      delayMs: 205,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _SectionTitle(
                            title: 'App Usage',
                            subtitle: 'Tap to see screen-time details',
                          ),
                          SizedBox(height: 14),
                          ActivityOverviewCard(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),

                    // ---- Foundation ---------------------------------------
                    _Reveal(
                      delayMs: 310,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle(title: 'Our Initiative'),
                          const SizedBox(height: 14),
                          FoundationCard(
                            info: data.foundation,
                            onKnowMore: vm.onKnowMoreFoundation,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: bottomPadding + 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ChildProfile _buildChildProfile({
    required ChildProfile fallback,
    required String? selectedName,
    required DeviceInfoResponse? info,
    required LiveStatusResponse? live,
    required DateTime? lastSyncAt,
  }) {
    final device = info?.deviceInfo;

    String firstNonEmpty(List<String?> values, String fallbackValue) {
      for (final v in values) {
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
      return fallbackValue;
    }

    return ChildProfile(
      name: firstNonEmpty([
        selectedName,
        live?.name,
        info?.name,
      ], fallback.name),
      avatarUrl: fallback.avatarUrl,
      // Online state comes from the live-status endpoint; fall back to
      // device-info, then the static placeholder.
      isOnline: live?.isOnline ?? info?.isOnline ?? fallback.isOnline,
      deviceModel: firstNonEmpty([
        device?.model,
        live?.deviceName,
        info?.deviceName,
      ], fallback.deviceModel),
      osVersion: firstNonEmpty([device?.osVersion], fallback.osVersion),
      // "Last sync" = the moment we last polled live-status.
      lastSync: _formatSync(lastSyncAt) ?? fallback.lastSync,
    );
  }

  /// Formats a timestamp as a short relative "ago" label.
  String? _formatSync(DateTime? dt) {
    if (dt == null) return null;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.day}/${two(dt.month)}';
  }
}

/// A soft decorative gradient + glow blobs behind the top of the page.
class _HeaderBackdrop extends StatelessWidget {
  const _HeaderBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: 340,
        width: double.infinity,
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFEAF1FF), AppColors.scaffold],
                ),
              ),
            ),
            Positioned(
              top: -50,
              right: -40,
              child: _blob(180, AppColors.primary.withValues(alpha: 0.14)),
            ),
            Positioned(
              top: 40,
              left: -50,
              child: _blob(150, AppColors.blueIcon.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Top greeting bar
/// ----------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  final ParentProfile parent;
  final int notificationCount;
  final VoidCallback? onParentTap;
  final VoidCallback onNotificationsTap;

  const _TopBar({
    required this.parent,
    required this.notificationCount,
    required this.onParentTap,
    required this.onNotificationsTap,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = parent.name.trim().isEmpty ? 'Parent' : parent.name.trim();
    final initials = parent.initials.trim().isEmpty
        ? _initialsFor(name)
        : parent.initials;

    return Row(
      children: [
        GestureDetector(
          onTap: onParentTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.blueIcon],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        _NotifBell(count: notificationCount, onTap: onNotificationsTap),
      ],
    );
  }
}

class _NotifBell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NotifBell({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textPrimary,
              size: 24,
            ),
            if (count > 0)
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.alert,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Child hero card (light, well-aligned)
/// ----------------------------------------------------------------------------
class _ChildHeroCard extends StatelessWidget {
  final ChildProfile child;
  final BatteryInfo? battery;
  final ConnectivityInfo? connectivity;
  final Widget dropdown;

  const _ChildHeroCard({
    required this.child,
    required this.battery,
    required this.connectivity,
    required this.dropdown,
  });

  @override
  Widget build(BuildContext context) {
    final online = child.isOnline;
    final batteryLevel = battery?.level;
    final charging = battery?.isCharging ?? false;
    final deviceLine = [
      child.deviceModel,
      child.osVersion,
    ].where((s) => s.trim().isNotEmpty).join('  •  ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, Color(0xFFF7FAFF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.blueIcon.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Gradient avatar ring + status dot
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.blueIcon],
                      ),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                      ),
                      child: const Icon(
                        Icons.account_circle,
                        size: 50,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (online)
                    const Positioned(right: 1, bottom: 1, child: _PulsingDot()),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name.isEmpty ? 'Child' : child.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (deviceLine.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.smartphone_rounded,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              deviceLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              dropdown,
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _InfoStat(
                  icon: online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: online ? AppColors.online : AppColors.textSecondary,
                  value: online ? 'Active' : 'Inactive',
                  label: 'Status',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoStat(
                  icon: charging
                      ? Icons.battery_charging_full_rounded
                      : _batteryIcon(batteryLevel),
                  color: charging
                      ? AppColors.online
                      : _batteryColor(batteryLevel),
                  value: batteryLevel != null ? '$batteryLevel%' : '—',
                  label: charging ? 'Charging' : 'Battery',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoStat(
                  icon: Icons.sync_rounded,
                  color: AppColors.blueIcon,
                  value: child.lastSync,
                  label: 'Last sync',
                ),
              ),
            ],
          ),
          if (connectivity != null) ...[
            const SizedBox(height: 10),
            _LiveDetails(connectivity: connectivity!, battery: battery),
          ],
        ],
      ),
    );
  }

  static IconData _batteryIcon(int? level) {
    if (level == null) return Icons.battery_unknown_rounded;
    if (level >= 90) return Icons.battery_full_rounded;
    if (level >= 50) return Icons.battery_5_bar_rounded;
    if (level >= 20) return Icons.battery_3_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  static Color _batteryColor(int? level) {
    if (level == null) return AppColors.textSecondary;
    if (level <= 20) return AppColors.alert;
    if (level <= 40) return AppColors.warning;
    return AppColors.primary;
  }
}

/// A single compact line of live connection + device chips. It scrolls
/// horizontally, so every detail (Wi-Fi name, link speed, battery state,
/// temperature, …) shows in full without making the card any taller.
class _LiveDetails extends StatelessWidget {
  final ConnectivityInfo connectivity;
  final BatteryInfo? battery;

  const _LiveDetails({required this.connectivity, this.battery});

  @override
  Widget build(BuildContext context) {
    final connected = connectivity.isConnected;
    final wifi = connectivity.wifi;
    final color = connected ? AppColors.blueIcon : AppColors.textSecondary;

    IconData connIcon;
    if (!connected) {
      connIcon = Icons.signal_wifi_connected_no_internet_4_rounded;
    } else if (connectivity.hasWifi) {
      connIcon = Icons.wifi_rounded;
    } else if (connectivity.hasMobile) {
      connIcon = Icons.signal_cellular_alt_rounded;
    } else {
      connIcon = Icons.lan_rounded;
    }

    String? clean(String? s) =>
        (s != null && s.trim().isNotEmpty) ? s.trim() : null;

    final ssid = connectivity.hasWifi ? clean(wifi.ssid) : null;
    final connLabel = ssid != null
        ? '${connectivity.label} • $ssid'
        : connectivity.label;
    final speed = wifi.linkSpeed != null ? '${wifi.linkSpeed} Mbps' : null;
    final battState = clean(battery?.state);
    final temp = battery?.temperature != null
        ? '${battery!.temperature!.toStringAsFixed(1)}°C'
        : null;

    final pills = <Widget>[
      _Pill(icon: connIcon, color: color, text: connLabel),
      if (speed != null)
        _Pill(
          icon: Icons.speed_rounded,
          color: AppColors.blueIcon,
          text: speed,
        ),
      if (battState != null)
        _Pill(
          icon: Icons.bolt_rounded,
          color: AppColors.online,
          text: _capitalize(battState),
        ),
      if (temp != null)
        _Pill(
          icon: Icons.thermostat_rounded,
          color: AppColors.warning,
          text: temp,
        ),
      if (battery?.isInBatterySaveMode ?? false)
        const _Pill(
          icon: Icons.battery_saver_rounded,
          color: AppColors.warning,
          text: 'Saver',
        ),
      if (connectivity.hasVpn)
        const _Pill(
          icon: Icons.vpn_lock_rounded,
          color: AppColors.primary,
          text: 'VPN',
        ),
    ];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: pills.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: pills[i]),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Pill({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            maxLines: 1,
            strutStyle: const StrutStyle(forceStrutHeight: true, height: 1.1),
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _InfoStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small green dot with a soft expanding pulse ring (online indicator).
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 8 + t * 8,
                height: 8 + t * 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.online.withValues(alpha: (1 - t) * 0.4),
                ),
              ),
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.online,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Entrance animation wrapper — fade + slide up, with an optional delay.
/// ----------------------------------------------------------------------------
class _Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _Reveal({required this.child, this.delayMs = 0});

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
      duration: const Duration(milliseconds: 480),
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
            offset: Offset(0, (1 - t) * 26),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// A consistent section heading.
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: subtitle != null ? 34 : 18,
          margin: const EdgeInsets.only(right: 10, top: 1),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.blueIcon],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Expanded(
          child: Column(
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
          ),
        ),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _box(width: 46, height: 46, radius: 23),
                    const SizedBox(width: 12),
                    Expanded(child: _box(height: 18)),
                    const SizedBox(width: 12),
                    _box(width: 46, height: 46, radius: 14),
                  ],
                ),
                const SizedBox(height: 20),
                _box(height: 150, radius: 22),
                const SizedBox(height: 24),
                _box(width: 160, height: 18, radius: 6),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                  ),
                  itemBuilder: (_, _) => _box(radius: 14),
                ),
                const SizedBox(height: 24),
                _box(height: 110, radius: 20),
              ],
            ),
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
