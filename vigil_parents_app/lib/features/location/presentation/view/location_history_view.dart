import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigil_parents_app/components/app_bottom_nav.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/location/models/location_model.dart';
import 'package:vigil_parents_app/features/location/presentation/view_model/location_history_viewmodel.dart';
import 'package:vigil_parents_app/features/location/presentation/widgets/home_location_card.dart'
    show kMapTileUrl, kMapSubdomains, kMapUserAgent;
import 'package:vigil_parents_app/features/location/presentation/widgets/location_marker.dart';

/// Full-screen location history: a trail of the child's recent whereabouts for
/// a chosen time window. The map renders immediately, then the points load in;
/// tapping a pin or list row focuses that point and reveals its address + time.
/// On-demand only — re-fetches on open and on each window change, no polling.
class LocationHistoryScreen extends ConsumerStatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  ConsumerState<LocationHistoryScreen> createState() =>
      _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends ConsumerState<LocationHistoryScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  // Tracks which dataset the camera has already framed, so we fit-to-bounds
  // once per fetch rather than on every rebuild.
  String? _fittedKey;
  // The point the camera last animated to (avoids re-animating on rebuilds).
  String? _focusedId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(selectedChildProvider).load();
      final id = ref.read(selectedChildProvider).selectedId;
      if (id == null) return;
      ref.read(locationHistoryViewModelProvider).load(id);
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onChildSelected(String childId) {
    setState(() {
      _fittedKey = null;
      _focusedId = null;
    });
    ref.read(locationHistoryViewModelProvider).load(childId);
  }

  /// A stable signature for a fetched trail — changes when the points change.
  String _keyFor(List<ChildLocation> pts) =>
      pts.isEmpty ? 'empty' : '${pts.length}:${pts.first.id}:${pts.last.id}';

  /// Frame the whole trail in view (or center on a single point).
  void _fitTrail(List<ChildLocation> pts) {
    if (!_mapReady || pts.isEmpty) return;
    if (pts.length == 1) {
      _mapController.move(pts.first.latLng, 16);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: pts.map((p) => p.latLng).toList(),
        padding: const EdgeInsets.all(56),
        maxZoom: 16.5,
      ),
    );
  }

  /// Smoothly tween the camera to [dest].
  void _animatedMove(LatLng dest, double zoom) {
    if (!_mapReady) {
      _mapController.move(dest, zoom);
      return;
    }
    final camera = _mapController.camera;
    final latTween =
        Tween<double>(begin: camera.center.latitude, end: dest.latitude);
    final lngTween =
        Tween<double>(begin: camera.center.longitude, end: dest.longitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: zoom);

    final controller = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    final anim = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);
    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(anim), lngTween.evaluate(anim)),
        zoomTween.evaluate(anim),
      );
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });
    controller.forward();
  }

  void _onPointTap(ChildLocation loc) {
    ref.read(locationHistoryViewModelProvider).select(loc);
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(locationHistoryViewModelProvider);
    final points = vm.locations;

    // Frame the trail once per new dataset.
    final key = _keyFor(points);
    if (points.isNotEmpty && key != _fittedKey) {
      _fittedKey = key;
      _focusedId = vm.selected?.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitTrail(points);
      });
    }

    // Animate to a freshly-selected point (e.g. from a list tap).
    final sel = vm.selected;
    if (sel != null && sel.id != _focusedId && key == _fittedKey) {
      _focusedId = sel.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapReady) _animatedMove(sel.latLng, 16.5);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppHeader(),
            _TitleBar(
              onChildSelected: _onChildSelected,
              count: points.length,
              hours: vm.hours,
              loading: vm.loading,
            ),
            _HoursSelector(
              selected: vm.hours,
              enabled: !vm.loading,
              onSelected: (h) => ref
                  .read(locationHistoryViewModelProvider)
                  .setHours(h),
            ),

            // ---- Map (renders first) + overlays --------------------------
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _Map(
                      controller: _mapController,
                      points: points,
                      selectedId: vm.selected?.id,
                      onReady: () {
                        _mapReady = true;
                        if (points.isNotEmpty) _fitTrail(points);
                      },
                      onPointTap: _onPointTap,
                    ),
                  ),

                  if (vm.loading)
                    const Positioned(top: 12, left: 0, right: 0, child: _LoadingPill()),

                  if (!vm.loading && points.isEmpty)
                    _EmptyOverlay(error: vm.error, hours: vm.hours),
                ],
              ),
            ),

            // ---- The same points, listed below the map -------------------
            Expanded(
              flex: 4,
              child: _HistoryList(
                points: points,
                selectedId: vm.selected?.id,
                loading: vm.loading,
                onTap: _onPointTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Map — trail polyline + numbered pins.
/// ----------------------------------------------------------------------------
class _Map extends StatelessWidget {
  final MapController controller;
  final List<ChildLocation> points;
  final String? selectedId;
  final VoidCallback onReady;
  final ValueChanged<ChildLocation> onPointTap;

  const _Map({
    required this.controller,
    required this.points,
    required this.selectedId,
    required this.onReady,
    required this.onPointTap,
  });

  @override
  Widget build(BuildContext context) {
    final center = points.isNotEmpty
        ? points.first.latLng
        : const LatLng(20.5937, 78.9629);

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: points.isNotEmpty ? 14 : 4,
        minZoom: 3,
        maxZoom: 18,
        onMapReady: onReady,
      ),
      children: [
        TileLayer(
          urlTemplate: kMapTileUrl,
          subdomains: kMapSubdomains,
          userAgentPackageName: kMapUserAgent,
        ),
        if (points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points.map((p) => p.latLng).toList(),
                strokeWidth: 4,
                color: AppColors.primary.withValues(alpha: 0.75),
                borderStrokeWidth: 2,
                borderColor: Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (var i = 0; i < points.length; i++)
              Marker(
                point: points[i].latLng,
                width: 80,
                height: 80,
                alignment: i == 0 ? Alignment.topCenter : Alignment.center,
                child: i == 0
                    ? LocationPin(
                        latest: true,
                        onTap: () => onPointTap(points[i]),
                      )
                    : _NumberPin(
                        // Number from the oldest (1) to newest so the path reads
                        // chronologically; index 0 is the live pin above.
                        number: points.length - i,
                        selected: points[i].id == selectedId,
                        onTap: () => onPointTap(points[i]),
                      ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A small numbered dot for a historical fix.
class _NumberPin extends StatelessWidget {
  final int number;
  final bool selected;
  final VoidCallback onTap;

  const _NumberPin({
    required this.number,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected ? 34.0 : 26.0;
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.primary : AppColors.blueIcon,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: (selected ? AppColors.primary : AppColors.blueIcon)
                    .withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: selected ? 13 : 11,
            ),
          ),
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Title + child picker.
/// ----------------------------------------------------------------------------
class _TitleBar extends StatelessWidget {
  final ValueChanged<String> onChildSelected;
  final int count;
  final int hours;
  final bool loading;

  const _TitleBar({
    required this.onChildSelected,
    required this.count,
    required this.hours,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = loading
        ? 'Loading…'
        : (count == 0
            ? 'No movement in the last ${hours}h'
            : '$count ${count == 1 ? 'point' : 'points'} · last ${hours}h');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location History',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
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
              shadowColor: Colors.black.withValues(alpha: 0.15),
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
/// Time-window chips (3h / 6h / 12h / 24h / 48h).
/// ----------------------------------------------------------------------------
class _HoursSelector extends StatelessWidget {
  final int selected;
  final bool enabled;
  final ValueChanged<int> onSelected;

  const _HoursSelector({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        itemCount: LocationHistoryViewModel.presetHours.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final h = LocationHistoryViewModel.presetHours[i];
          final active = h == selected;
          return GestureDetector(
            onTap: enabled && !active ? () => onSelected(h) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.cardBorder,
                ),
              ),
              child: Text(
                'Last ${h}h',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Timeline of points beneath the map — a vertical track with a dot per fix,
/// the clock time on the left and the place on the right (Maps-style).
/// ----------------------------------------------------------------------------
class _HistoryList extends StatelessWidget {
  final List<ChildLocation> points;
  final String? selectedId;
  final bool loading;
  final ValueChanged<ChildLocation> onTap;

  const _HistoryList({
    required this.points,
    required this.selectedId,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          // Grab handle.
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          if (points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.timeline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Timeline',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${points.length} ${points.length == 1 ? 'stop' : 'stops'}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: (loading && points.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : points.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No location points to show for this window.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: points.length,
                        itemBuilder: (context, i) {
                          final p = points[i];
                          return _TimelineTile(
                            location: p,
                            isFirst: i == 0,
                            isLast: i == points.length - 1,
                            isLatest: i == 0,
                            selected: p.id == selectedId,
                            onTap: () => onTap(p),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final ChildLocation location;
  final bool isFirst;
  final bool isLast;
  final bool isLatest;
  final bool selected;
  final VoidCallback onTap;

  const _TimelineTile({
    required this.location,
    required this.isFirst,
    required this.isLast,
    required this.isLatest,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isLatest ? AppColors.primary : AppColors.blueIcon;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Time column ---------------------------------------------
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: 14, right: 8),
              child: Text(
                location.timeLabel,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: isLatest ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
          ),

          // ---- Connector track + dot -----------------------------------
          SizedBox(
            width: 22,
            child: Column(
              children: [
                // top segment
                SizedBox(
                  height: 14,
                  child: Center(
                    child: Container(
                      width: 2,
                      color: isFirst
                          ? Colors.transparent
                          : AppColors.cardBorder,
                    ),
                  ),
                ),
                // dot
                Container(
                  width: isLatest ? 16 : 13,
                  height: isLatest ? 16 : 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    border: Border.all(
                      color: selected ? accent : Colors.white,
                      width: selected ? 3 : 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                // bottom segment (fills remaining height)
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : AppColors.cardBorder,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---- Content card --------------------------------------------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 6, top: 6, bottom: 6),
              child: Material(
                color: selected ? AppColors.primaryLight : AppColors.scaffold,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.cardBorder,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      location.address.isNotEmpty
                                          ? location.address
                                          : 'Unknown place',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (isLatest) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Now',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                location.relativeLabel,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.near_me_rounded,
                          size: 16,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Small map overlays.
/// ----------------------------------------------------------------------------
class _LoadingPill extends StatelessWidget {
  const _LoadingPill();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'Loading history…',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOverlay extends StatelessWidget {
  final String? error;
  final int hours;
  const _EmptyOverlay({required this.error, required this.hours});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 18),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                error != null
                    ? Icons.error_outline_rounded
                    : Icons.timeline_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              error ?? 'No history in the last ${hours}h',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try a longer time window, or check back once the device reports more locations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
