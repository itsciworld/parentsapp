import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/components/app_bottom_nav.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/location/models/location_model.dart';
import 'package:vigil_parents_app/features/location/presentation/view_model/location_history_viewmodel.dart';

class LocationHistoryScreen extends ConsumerStatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  ConsumerState<LocationHistoryScreen> createState() =>
      _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends ConsumerState<LocationHistoryScreen> {
  GoogleMapController? _mapController;

  // Tracks which dataset the camera has already framed, so we fit-to-bounds
  // once per fetch rather than on every rebuild.
  String? _fittedKey;
  // The point the camera last animated to (avoids re-animating on rebuilds).
  String? _focusedId;

  // Time-labelled pin bitmaps for the current points, rebuilt whenever the
  // trail or the selected point changes. Signature guards against rebuilding
  // the same set every frame.
  Set<Marker> _markers = {};
  String? _markersSig;

  // Cache for marker bitmaps to avoid regenerating them on every rebuild
  final Map<String, BitmapDescriptor> _markerCache = {};

  // Flag to prevent multiple simultaneous marker builds
  bool _buildingMarkers = false;

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
    _mapController?.dispose();
    _markerCache.clear();
    super.dispose();
  }

  void _onChildSelected(String childId) {
    setState(() {
      _fittedKey = null;
      _focusedId = null;
      _markerCache.clear(); // Clear cache when switching children
    });
    ref.read(locationHistoryViewModelProvider).load(childId);
  }

  /// A stable signature for a fetched trail — changes when the points change.
  String _keyFor(List<ChildLocation> pts) =>
      pts.isEmpty ? 'empty' : '${pts.length}:${pts.first.id}:${pts.last.id}';

  /// Frame the whole trail in view (or center on a single point).
  void _fitTrail(List<ChildLocation> pts) {
    final controller = _mapController;
    if (controller == null || pts.isEmpty) return;

    final bounds = _boundsFor(pts);
    // Total lat+lng spread of the trail, in degrees (~0.0005° ≈ 55 m).
    final span =
        (bounds.northeast.latitude - bounds.southwest.latitude).abs() +
        (bounds.northeast.longitude - bounds.southwest.longitude).abs();

    // One point, or the child barely moved (all fixes in ~one place): just
    // centre on it. Fitting a near-zero bounds would over-zoom or throw.
    if (pts.length == 1 || span < 0.0005) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(pts.first.latitude, pts.first.longitude),
          16,
        ),
      );
      return;
    }
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 56));
  }

  /// Smoothly animate the camera to [lat]/[lng]. Google Maps tweens natively.
  void _animatedMove(double lat, double lng, double zoom) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), zoom),
    );
  }

  /// The bounding box that contains every point in [pts].
  LatLngBounds _boundsFor(List<ChildLocation> pts) {
    var minLat = pts.first.latitude, maxLat = pts.first.latitude;
    var minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _onPointTap(ChildLocation loc) {
    ref.read(locationHistoryViewModelProvider).select(loc);
  }

  /// Rebuilds the time-labelled pin set for [pts]. Each pin is a pill showing
  /// the clock time of that fix (latest in green, the rest in blue, the
  /// selected one highlighted), so the map reads "which time → which place" at
  /// a glance. The full address stays in the tap-to-open info window.
  Future<void> _buildMarkers(
    List<ChildLocation> pts,
    String? selectedId,
  ) async {
    // Prevent multiple simultaneous builds
    if (_buildingMarkers) return;
    _buildingMarkers = true;

    try {
      final markers = <Marker>{};

      // Build markers in batches to avoid blocking the UI
      const batchSize = 10;
      for (var startIdx = 0; startIdx < pts.length; startIdx += batchSize) {
        final endIdx = (startIdx + batchSize).clamp(0, pts.length);

        for (var i = startIdx; i < endIdx; i++) {
          final p = pts[i];
          final isLatest = i == 0;
          final number = pts.length - i; // oldest = 1, chronological
          final selected = p.id == selectedId;

          // Create cache key based on marker properties
          final cacheKey = 'n${number}_l$isLatest\_s$selected';

          // Try to get from cache first
          BitmapDescriptor icon;
          if (_markerCache.containsKey(cacheKey)) {
            icon = _markerCache[cacheKey]!;
          } else {
            icon = await _numberMarkerBitmap(
              number: number,
              isLatest: isLatest,
              selected: selected,
            );
            _markerCache[cacheKey] = icon;
          }

          markers.add(
            Marker(
              markerId: MarkerId(p.id),
              position: LatLng(p.latitude, p.longitude),
              icon: icon,
              // Circle pin — anchor at its centre on the coordinate.
              anchor: const Offset(0.5, 0.5),
              // Higher zIndex for the latest / selected so they sit above the rest.
              zIndexInt: isLatest ? 2 : (selected ? 1 : 0),
              infoWindow: InfoWindow(
                title: isLatest
                    ? 'Stop $number · Now · ${p.timeLabel}'
                    : 'Stop $number · ${p.timeLabel}',
                snippet: p.address.isNotEmpty ? p.address : p.coordinates,
              ),
              onTap: () => _onPointTap(p),
            ),
          );
        }

        // Yield to UI thread between batches
        await Future.delayed(Duration.zero);
      }

      if (mounted) setState(() => _markers = markers);
    } finally {
      _buildingMarkers = false;
    }
  }

  /// Draws a small numbered circle to a [BitmapDescriptor] for use as a Google
  /// Maps marker icon. The number matches the stop's position in the timeline
  /// list below (oldest = 1). Latest = green, selected = navy + larger, the
  /// rest = blue.
  ///
  /// Optimized for iOS and Android performance.
  Future<BitmapDescriptor> _numberMarkerBitmap({
    required int number,
    required bool isLatest,
    required bool selected,
  }) async {
    // Limit DPR to prevent excessive memory usage on high-DPI devices
    final dpr = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    final Color fill = isLatest
        ? AppColors.primary
        : (selected ? AppColors.headerBottom : AppColors.blueIcon);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const border = 2.5;
    // Diameter grows a touch for the selected/latest pins so they stand out.
    final diameter = (selected || isLatest) ? 32.0 : 27.0;
    final total = diameter + border * 2;
    final center = Offset(total / 2, total / 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);

    // Soft drop shadow - simplified for better performance
    canvas.drawCircle(
      center.translate(0, 1.5),
      diameter / 2 + border,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    // White ring + coloured fill.
    canvas.drawCircle(
      center,
      diameter / 2 + border,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(center, diameter / 2, Paint()..color = fill);
    // Centred number.
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    final image = await recorder.endRecording().toImage(
      (total * dpr).ceil(),
      (total * dpr).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
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
        if (mounted) _animatedMove(sel.latitude, sel.longitude, 16.5);
      });
    }

    // (Re)build the time-pill markers when the trail or selection changes.
    final markersSig = '$key|${sel?.id}';
    if (markersSig != _markersSig) {
      _markersSig = markersSig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _buildMarkers(points, sel?.id);
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
              onSelected: (h) =>
                  ref.read(locationHistoryViewModelProvider).setHours(h),
            ),

            // ---- Map (renders first) + overlays --------------------------
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _Map(
                      points: points,
                      markers: _markers,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (points.isNotEmpty) _fitTrail(points);
                      },
                    ),
                  ),

                  if (vm.loading)
                    const Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: _LoadingPill(),
                    ),

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
  final List<ChildLocation> points;
  final Set<Marker> markers;
  final ValueChanged<GoogleMapController> onMapCreated;

  const _Map({
    required this.points,
    required this.markers,
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    final center = points.isNotEmpty
        ? LatLng(points.first.latitude, points.first.longitude)
        : const LatLng(20.5937, 78.9629);

    // The trail line, drawn oldest → newest as a dotted path so it reads as
    // "the child moved from stop ① → ② → ③…". The numbered pins + timeline
    // tell you the time at each stop.
    final polylines = <Polyline>{
      if (points.length > 1)
        Polyline(
          polylineId: const PolylineId('trail'),
          points: [for (final p in points) LatLng(p.latitude, p.longitude)],
          color: AppColors.headerBottom,
          width: 3,
          patterns: [PatternItem.dot, PatternItem.gap(10)],
        ),
    };

    return GoogleMap(
      onMapCreated: onMapCreated,
      initialCameraPosition: CameraPosition(
        target: center,
        zoom: points.isNotEmpty ? 14 : 4,
      ),
      polylines: polylines,
      markers: markers,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      // Performance optimizations for smooth rendering on iOS and Android
      compassEnabled: false,
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: false,
      buildingsEnabled: false,
      indoorViewEnabled: false,
      trafficEnabled: false,
      // Lite mode for better performance (Android only, ignored on iOS)
      liteModeEnabled: false,
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
          BoxShadow(
            color: Colors.black12,
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
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
                    // Performance optimizations for smooth scrolling
                    physics: const BouncingScrollPhysics(),
                    cacheExtent: 200,
                    itemBuilder: (context, i) {
                      final p = points[i];
                      return _TimelineTile(
                        location: p,
                        number: points.length - i, // matches the map pin
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
  final int number;
  final bool isFirst;
  final bool isLast;
  final bool isLatest;
  final bool selected;
  final VoidCallback onTap;

  const _TimelineTile({
    required this.location,
    required this.number,
    required this.isFirst,
    required this.isLast,
    required this.isLatest,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isLatest
        ? AppColors.primary
        : (selected ? AppColors.headerBottom : AppColors.blueIcon);

    // RepaintBoundary isolates each tile's repaints for better performance
    return RepaintBoundary(
      child: IntrinsicHeight(
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

            // ---- Connector track + numbered dot --------------------------
            SizedBox(
              width: 30,
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
                  // numbered dot — same number as the map pin
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      border: Border.all(
                        color: Colors.white,
                        width: selected ? 3 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // bottom segment (fills remaining height)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: isLast
                            ? Colors.transparent
                            : AppColors.cardBorder,
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
            ),
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
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
            ),
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
