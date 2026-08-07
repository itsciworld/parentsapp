import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vigil_parents_app/core/services/background/sync_signals.dart';
import 'package:vigil_parents_app/core/utils/polling_screen.dart';
import 'package:vigil_parents_app/components/app_bottom_nav.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/no_child_linked_view.dart';
import 'package:vigil_parents_app/features/device_info/models/device_info_model.dart';
import 'package:vigil_parents_app/features/device_info/presentation/view_model/device_info_viewmodel.dart';
import 'package:vigil_parents_app/features/live_status/models/live_status_model.dart';
import 'package:vigil_parents_app/features/live_status/presentation/view_model/live_status_viewmodel.dart';

/// Full device-details screen reachable from the "Device Info" monitoring tool.
///
/// Combines two endpoints we already use elsewhere:
///   • /api/children/{id}/device-info   → hardware / OS / app build
///   • /api/children/{id}/live-status   → live battery + connectivity + session
class DeviceInfoScreen extends ConsumerStatefulWidget {
  const DeviceInfoScreen({super.key});

  @override
  ConsumerState<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends ConsumerState<DeviceInfoScreen>
    with WidgetsBindingObserver, PollingScreen<DeviceInfoScreen> {
  @override
  Duration get pollInterval => const Duration(seconds: 15);

  @override
  String? get pollFeature => SyncFeature.liveStatus;

  @override
  void onPoll() => ref.read(liveStatusViewModelProvider).refresh();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(selectedChildProvider).load();
      final id = ref.read(selectedChildProvider).selectedId;
      if (id != null) _loadFor(id);
    });
    startPolling();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  void _loadFor(String childId) {
    ref.read(deviceInfoViewModelProvider).load(childId);
    ref.read(liveStatusViewModelProvider).load(childId);
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref
          .read(deviceInfoViewModelProvider)
          .load(ref.read(selectedChildProvider).selectedId ?? ''),
      ref.read(liveStatusViewModelProvider).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final selectedChild = ref.watch(selectedChildProvider);
    final deviceVm = ref.watch(deviceInfoViewModelProvider);
    final liveVm = ref.watch(liveStatusViewModelProvider);

    final noChild = selectedChild.initialized && selectedChild.children.isEmpty;
    final info = deviceVm.info;
    final live = liveVm.status;

    final loading =
        (deviceVm.loading && info == null) || (liveVm.loading && live == null);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppHeader(onActionTap: () {}),
            ),
            const SizedBox(height: 16),
            if (noChild)
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: NoChildLinkedView(
                      refreshing: selectedChild.loading,
                      onRefresh: () =>
                          ref.read(selectedChildProvider).load(force: true),
                    ),
                  ),
                ),
              )
            else ...[
              // Child picker — right-aligned, like the other monitoring views.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: ChildSelectorDropdown(onChanged: _loadFor),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primary,
                  child: loading
                      ? const _LoadingBody()
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          children: _sections(
                            info: info,
                            live: live,
                            lastSyncAt: liveVm.lastSyncAt,
                            error: deviceVm.error ?? liveVm.error,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _sections({
    required DeviceInfoResponse? info,
    required LiveStatusResponse? live,
    required DateTime? lastSyncAt,
    required String? error,
  }) {
    final battery = live?.battery;
    final conn = live?.connectivity;
    final device = info?.deviceInfo;

    var delay = 0;
    Widget reveal(Widget child) {
      final w = _Reveal(delayMs: delay, child: child);
      delay += 80;
      return w;
    }

    return [
      if (error != null) ...[
        reveal(_ErrorBanner(message: error)),
        const SizedBox(height: 14),
      ],

      // ---- Battery -----------------------------------------------------
      reveal(
        _SectionCard(
          icon: Icons.battery_charging_full_rounded,
          accent: AppColors.online,
          title: 'Battery',
          child: _BatterySection(battery: battery),
        ),
      ),
      const SizedBox(height: 14),

      // ---- Connectivity ------------------------------------------------
      reveal(
        _SectionCard(
          icon: Icons.wifi_rounded,
          accent: AppColors.blueIcon,
          title: 'Connectivity',
          child: _ConnectivitySection(conn: conn),
        ),
      ),
      const SizedBox(height: 14),

      // ---- Live session ------------------------------------------------
      reveal(
        _SectionCard(
          icon: Icons.sensors_rounded,
          accent: AppColors.primary,
          title: 'Live Session',
          child: _StatusSection(live: live, lastSyncAt: lastSyncAt),
        ),
      ),
      const SizedBox(height: 14),

      // ---- Device / hardware -------------------------------------------
      reveal(
        _SectionCard(
          icon: Icons.smartphone_rounded,
          accent: AppColors.indigoIcon,
          title: 'Device',
          child: _DeviceSection(device: device, deviceName: info?.deviceName),
        ),
      ),
    ];
  }
}

/// ----------------------------------------------------------------------------
/// Section card shell
/// ----------------------------------------------------------------------------
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 19),
              ),
              const SizedBox(width: 11),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Battery section
/// ----------------------------------------------------------------------------
class _BatterySection extends StatelessWidget {
  final BatteryInfo? battery;
  const _BatterySection({required this.battery});

  @override
  Widget build(BuildContext context) {
    final b = battery;
    final level = b?.level;
    final charging = b?.isCharging ?? false;
    final saver = b?.isInBatterySaveMode ?? false;
    final color = _levelColor(level);

    final stateLabel = charging
        ? 'Charging'
        : (_cap(b?.state) ?? (level == null ? 'No data' : 'Discharging'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Hero: battery glyph + big percentage ------------------------
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.10),
                color.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              _BatteryGlyph(level: level, charging: charging, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: (level ?? 0).toDouble()),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        level != null ? '${value.round()}%' : '—',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: color,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          charging
                              ? Icons.bolt_rounded
                              : Icons.power_settings_new_rounded,
                          size: 14,
                          color: charging
                              ? AppColors.online
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          stateLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: charging
                                ? AppColors.online
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (saver)
                const _MiniBadge(
                  icon: Icons.battery_saver_rounded,
                  label: 'Saver',
                  color: AppColors.warning,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ---- Metrics -----------------------------------------------------
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricChip(
              icon: Icons.power_settings_new_rounded,
              label: 'Power saver',
              value: saver ? 'On' : 'Off',
              color: saver ? AppColors.warning : AppColors.textSecondary,
            ),
            if (b?.temperature != null)
              _MetricChip(
                icon: Icons.thermostat_rounded,
                label: 'Temperature',
                value: '${b!.temperature!.toStringAsFixed(1)}°C',
                color: AppColors.alert,
              ),
            if (b?.voltage != null)
              _MetricChip(
                icon: Icons.electric_bolt_rounded,
                label: 'Voltage',
                value: '${b!.voltage!.toStringAsFixed(2)} V',
                color: AppColors.blueIcon,
              ),
          ],
        ),
      ],
    );
  }
}

/// A realistic horizontal battery shape with an animated, color-coded fill and
/// a charging bolt overlay.
class _BatteryGlyph extends StatelessWidget {
  final int? level;
  final bool charging;
  final Color color;
  const _BatteryGlyph({
    required this.level,
    required this.charging,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.45), width: 2),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (level ?? 0).clamp(0, 100) / 100),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: value == 0 ? 0.0 : value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.65), color],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              if (charging)
                const Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        // Terminal nub.
        Container(
          width: 3,
          height: 11,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.45),
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

/// A compact labeled metric chip (icon + value over a soft label).
class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small pill used on the battery hero (e.g. "Saver").
class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Connectivity section
/// ----------------------------------------------------------------------------
class _ConnectivitySection extends StatelessWidget {
  final ConnectivityInfo? conn;
  const _ConnectivitySection({required this.conn});

  @override
  Widget build(BuildContext context) {
    final c = conn;
    if (c == null) {
      return const _EmptyHint(text: 'No connectivity data yet');
    }

    final wifi = c.wifi;
    String? v(String? s) =>
        (s != null && s.trim().isNotEmpty) ? s.trim() : null;

    final ssid = v(wifi.ssid);

    final rows = <Widget>[
      _InfoRow(
        label: 'Connection',
        value: (c.hasWifi && ssid != null) ? '${c.label} • $ssid' : c.label,
      ),
      // Always surface the Wi-Fi network when connected over Wi-Fi — show the
      // name, or a clear fallback when the device doesn't report it.
      if (c.hasWifi)
        _InfoRow(
          label: 'Wi-Fi network',
          value: ssid ?? 'Not available',
          valueColor: ssid != null ? AppColors.blueIcon : null,
        ),
      if (v(wifi.bssid) != null)
        _InfoRow(label: 'BSSID', value: v(wifi.bssid)!),
      if (v(wifi.ipAddress) != null)
        _InfoRow(label: 'IP address', value: v(wifi.ipAddress)!),
      if (wifi.linkSpeed != null)
        _InfoRow(label: 'Link speed', value: '${wifi.linkSpeed} Mbps'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Flag('Wi-Fi', c.hasWifi, Icons.wifi_rounded),
            _Flag('Mobile', c.hasMobile, Icons.signal_cellular_alt_rounded),
            _Flag('Ethernet', c.hasEthernet, Icons.lan_rounded),
            _Flag('Bluetooth', c.hasBluetooth, Icons.bluetooth_rounded),
            _Flag('VPN', c.hasVpn, Icons.vpn_lock_rounded),
          ],
        ),
        const SizedBox(height: 14),
        ..._withDividers(rows),
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// Live session section
/// ----------------------------------------------------------------------------
class _StatusSection extends StatelessWidget {
  final LiveStatusResponse? live;
  final DateTime? lastSyncAt;
  const _StatusSection({required this.live, required this.lastSyncAt});

  @override
  Widget build(BuildContext context) {
    final l = live;
    final rows = <Widget>[
      _InfoRow(
        label: 'Status',
        value: (l?.isOnline ?? false) ? 'Online' : 'Offline',
        valueColor: (l?.isOnline ?? false) ? AppColors.online : null,
      ),
      _InfoRow(
        label: 'Session',
        value: (l?.sessionActive ?? false) ? 'Active' : 'Inactive',
        valueColor: (l?.sessionActive ?? false) ? AppColors.online : null,
      ),
      _InfoRow(label: 'Last seen', value: _fmt(l?.lastSeen)),
      _InfoRow(label: 'Status updated', value: _fmt(l?.liveStatusUpdatedAt)),
      _InfoRow(label: 'Last sync', value: _rel(lastSyncAt)),
    ];
    return Column(children: _withDividers(rows));
  }

  static String _rel(DateTime? dt) {
    if (dt == null) return '—';
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

/// ----------------------------------------------------------------------------
/// Device / hardware section
/// ----------------------------------------------------------------------------
class _DeviceSection extends StatelessWidget {
  final DeviceDetails? device;
  final String? deviceName;
  const _DeviceSection({required this.device, required this.deviceName});

  @override
  Widget build(BuildContext context) {
    final d = device;
    if (d == null || d.isEmpty) {
      return _EmptyHint(
        text: (deviceName != null && deviceName!.trim().isNotEmpty)
            ? deviceName!
            : 'Device details not reported yet',
      );
    }

    String? v(String? s) =>
        (s != null && s.trim().isNotEmpty) ? s.trim() : null;

    final rows = <Widget>[
      if (v(d.manufacturer) != null)
        _InfoRow(label: 'Manufacturer', value: d.manufacturer),
      if (v(d.model) != null) _InfoRow(label: 'Model', value: d.model),
      if (v(d.osVersion) != null)
        _InfoRow(label: 'OS version', value: d.osVersion),
      if (v(d.sdkVersion) != null) _InfoRow(label: 'SDK', value: d.sdkVersion),
      if (v(d.appVersion) != null)
        _InfoRow(label: 'App version', value: d.appVersion),
      if (v(d.deviceId) != null)
        _InfoRow(label: 'Device ID', value: d.deviceId),
      if (v(d.lastUpdated) != null)
        _InfoRow(label: 'Updated', value: _fmt(d.lastUpdated)),
    ];
    return Column(children: _withDividers(rows));
  }
}

/// ----------------------------------------------------------------------------
/// Small shared widgets / helpers
/// ----------------------------------------------------------------------------
class _Flag extends StatelessWidget {
  final String label;
  final bool on;
  final IconData icon;
  const _Flag(this.label, this.on, this.icon);

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.blueIcon : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: on ? color.withValues(alpha: 0.10) : AppColors.scaffold,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: on ? color.withValues(alpha: 0.30) : AppColors.cardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: on ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.alert.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.alert.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.alert, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: AppColors.alert),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Column(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fade + slide-up entrance used to stagger the section cards.
class _Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _Reveal({required this.child, this.delayMs = 0});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  @override
  void initState() {
    super.initState();
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
            offset: Offset(0, (1 - t) * 24),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ── module-level helpers ────────────────────────────────────────────────────

/// Battery level → status color, matching the Home card thresholds.
Color _levelColor(int? level) {
  if (level == null) return AppColors.textSecondary;
  if (level <= 20) return AppColors.alert;
  if (level <= 40) return AppColors.warning;
  return AppColors.online;
}

/// Capitalizes the first letter; returns null for null/empty input.
String? _cap(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final t = s.trim();
  return '${t[0].toUpperCase()}${t.substring(1)}';
}

/// Formats an ISO timestamp as "11 Jun 2026, 14:05". Falls back to "—".
String _fmt(String? iso) {
  if (iso == null || iso.trim().isEmpty) return '—';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return iso;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
      '${two(dt.hour)}:${two(dt.minute)}';
}

/// Inserts hairline dividers between info rows.
List<Widget> _withDividers(List<Widget> rows) {
  final out = <Widget>[];
  for (var i = 0; i < rows.length; i++) {
    out.add(rows[i]);
    if (i != rows.length - 1) {
      out.add(const Divider(height: 1, color: AppColors.cardBorder));
    }
  }
  return out;
}
