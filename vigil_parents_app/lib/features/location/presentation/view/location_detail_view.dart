import 'dart:async';

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
import 'package:vigil_parents_app/features/location/presentation/view_model/location_viewmodel.dart';
import 'package:vigil_parents_app/features/location/presentation/view/location_history_view.dart';
import 'package:vigil_parents_app/features/location/presentation/widgets/home_location_card.dart'
    show kMapTileUrl, kMapSubdomains, kMapUserAgent;
import 'package:vigil_parents_app/features/location/presentation/widgets/location_marker.dart';

/// Full-screen view of the child's current (latest) location: a clean
/// interactive map with a single live pin, a child picker that matches the SMS
/// screen, and a card showing the latest address. Polls so the pin tracks the
/// freshest fix from the API.
class LocationDetailScreen extends ConsumerStatefulWidget {
  const LocationDetailScreen({super.key});

  @override
  ConsumerState<LocationDetailScreen> createState() =>
      _LocationDetailScreenState();
}

class _LocationDetailScreenState extends ConsumerState<LocationDetailScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  // Id of the fix the camera is currently centered on, so we recenter once when
  // a new latest location arrives rather than on every rebuild.
  String? _centeredId;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Always fetch the freshest fix on open so a newly-recorded location shows
    // up even if the home card primed an older cache.
    Future.microtask(() async {
      await ref.read(selectedChildProvider).load();
      final vm = ref.read(locationViewModelProvider);
      final id = ref.read(selectedChildProvider).selectedId;
      if (id == null) return;
      if (vm.childId == id && vm.latest != null) {
        vm.refresh(); // keep the current pin visible while updating
      } else {
        vm.load(id);
      }
    });

    // Keep the pin live while the screen is open.
    _pollTimer = Timer.periodic(const Duration(seconds: 18), (_) {
      ref.read(locationViewModelProvider).refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _onChildSelected(String childId) {
    setState(() => _centeredId = null);
    ref.read(locationViewModelProvider).load(childId);
  }

  /// Smoothly tweens the camera (center + zoom) to [dest].
  void _animatedMove(LatLng dest, double zoom) {
    if (!_mapReady) {
      _mapController.move(dest, zoom);
      return;
    }
    final camera = _mapController.camera;
    final latTween = Tween<double>(
      begin: camera.center.latitude,
      end: dest.latitude,
    );
    final lngTween = Tween<double>(
      begin: camera.center.longitude,
      end: dest.longitude,
    );
    final zoomTween = Tween<double>(begin: camera.zoom, end: zoom);

    final controller = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    final anim = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubic,
    );
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

  void _recenter(ChildLocation latest) => _animatedMove(latest.latLng, 16.5);

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(locationViewModelProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final latest = vm.latest;

    // Recenter whenever a new latest fix arrives (or the child changes).
    if (latest != null && latest.id != _centeredId) {
      _centeredId = latest.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapReady) _animatedMove(latest.latLng, 16);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ---- VIGIL logo header (same as SMS / other views) ----------
            const AppHeader(),

            // ---- Title + child picker -----------------------------------
            _TitleBar(
              onChildSelected: _onChildSelected,
              hasFix: latest != null,
              loading: vm.loading,
            ),

            // ---- Map + overlays -----------------------------------------
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _Map(
                      controller: _mapController,
                      latest: latest,
                      onReady: () {
                        _mapReady = true;
                        if (latest != null) {
                          _mapController.move(latest.latLng, 16);
                        }
                      },
                    ),
                  ),

                  if (vm.loading && latest == null)
                    const Center(child: CircularProgressIndicator())
                  else if (latest == null)
                    _EmptyOverlay(error: vm.error),

                  // History entry — opens the recent-trail screen.
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _HistoryButton(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LocationHistoryScreen(),
                        ),
                      ),
                    ),
                  ),

                  if (latest != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16 + MediaQuery.of(context).padding.bottom,
                      child: _LatestCard(
                        location: latest,
                        childName: selectedChild.selected?.name,
                        onRecenter: () => _recenter(latest),
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

/// ----------------------------------------------------------------------------
/// Map — a single live pin for the latest fix.
/// ----------------------------------------------------------------------------
class _Map extends StatelessWidget {
  final MapController controller;
  final ChildLocation? latest;
  final VoidCallback onReady;

  const _Map({
    required this.controller,
    required this.latest,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    final center = latest?.latLng ?? const LatLng(20.5937, 78.9629);

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
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
        if (latest != null)
          MarkerLayer(
            markers: [
              Marker(
                point: latest!.latLng,
                width: 80,
                height: 80,
                alignment: Alignment.topCenter,
                child: const LocationPin(latest: true),
              ),
            ],
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
  final bool hasFix;
  final bool loading;

  const _TitleBar({
    required this.onChildSelected,
    required this.hasFix,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Location',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  loading
                      ? 'Updating…'
                      : (hasFix ? 'Current location' : 'No location yet'),
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
          // Same picker behaviour as the SMS screen.
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

/// A pill button overlaid on the map that opens the location history screen.
class _HistoryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HistoryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'History',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Bottom card describing the latest fix — slides up on entrance.
/// ----------------------------------------------------------------------------
class _LatestCard extends StatefulWidget {
  final ChildLocation location;
  final String? childName;
  final VoidCallback onRecenter;

  const _LatestCard({
    required this.location,
    required this.childName,
    required this.onRecenter,
  });

  @override
  State<_LatestCard> createState() => _LatestCardState();
}

class _LatestCardState extends State<_LatestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.childName == null || widget.childName!.trim().isEmpty)
        ? 'Current Location'
        : "${widget.childName!.trim()}'s Location";

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 40),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Live',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.location.address.isNotEmpty
                        ? widget.location.address
                        : 'Unknown place',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.gps_fixed_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.location.coordinates,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Recenter button.
            Material(
              color: AppColors.primaryLight,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onRecenter,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.gps_fixed_rounded,
                    color: AppColors.primary,
                    size: 22,
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

class _EmptyOverlay extends StatelessWidget {
  final String? error;
  const _EmptyOverlay({this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                error != null
                    ? Icons.location_off_rounded
                    : Icons.location_searching_rounded,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error ?? 'No location recorded yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "The current location will appear here once the child's device reports it.",
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
