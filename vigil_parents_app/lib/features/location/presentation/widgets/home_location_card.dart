import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/child/models/child_permissions_model.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/child_permissions_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/location/models/location_model.dart';
import 'package:vigil_parents_app/features/location/presentation/view/location_detail_view.dart';
import 'package:vigil_parents_app/features/location/presentation/view_model/location_viewmodel.dart';
import 'package:vigil_parents_app/features/location/presentation/widgets/person_marker.dart';

/// Home-page "Live Location" card: a live OpenStreetMap preview centered on the
/// selected child's most recent fix, with an expand icon that opens the full
/// history map.
class HomeLocationCard extends ConsumerStatefulWidget {
  const HomeLocationCard({super.key});

  @override
  ConsumerState<HomeLocationCard> createState() => _HomeLocationCardState();
}

class _HomeLocationCardState extends ConsumerState<HomeLocationCard> {
  /// The child we have already asked the view model for, so neither a rebuild
  /// nor a failed request can turn this into a request loop.
  String? _requestedFor;

  @override
  void initState() {
    super.initState();
    _ensureLoaded();
  }

  /// Fetches this card's own data instead of relying on [HomeScreen]'s one-shot
  /// startup fetch.
  ///
  /// That fetch runs once, in a microtask, before this card is mounted — and
  /// when it doesn't land (the child list was still resolving, the request
  /// failed, the screen was rebuilt) nothing retried: the home poll timer calls
  /// `refresh()`, which returned immediately while the view model had never
  /// been given a child. The card then stayed empty until the detail screen —
  /// the only other caller of `load` — was opened, which is exactly the
  /// "location only shows up after I expand it" report.
  void _ensureLoaded() {
    final childId = ref.read(selectedChildProvider).selectedId;
    if (childId == null || childId == _requestedFor) return;
    _requestedFor = childId;

    // Home may already have this child in flight — don't duplicate its request.
    final vm = ref.read(locationViewModelProvider);
    if (vm.childId == childId && (vm.latest != null || vm.loading)) return;

    // Deferred: this can run from a provider notification, and `load` notifies
    // synchronously when it shows the loader.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) vm.load(childId, showLoader: vm.latest == null);
    });
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => const LocationDetailScreen(),
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
  Widget build(BuildContext context) {
    // The card can mount before the child list has resolved, and the selection
    // can change under us from the hero card's dropdown — either way this is
    // where we notice we're showing a child we never asked for.
    ref.listen(selectedChildProvider, (_, _) => _ensureLoaded());

    final vm = ref.watch(locationViewModelProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final childName = selectedChild.selected?.name;
    final latest = vm.latest;

    // The child is not sharing location, so the map has nothing to plot —
    // say so rather than leaving a permanently empty "No location yet".
    final permissionDenied = ref
        .watch(childPermissionsProvider)
        .isDenied(selectedChild.selectedId, ChildFeature.location);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Map preview ------------------------------------------------
          SizedBox(
            height: 170,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _MapBody(
                  vm: vm,
                  latest: latest,
                  permissionDenied: permissionDenied,
                ),

                // Top gradient scrim so the chips stay legible over the map.
                IgnorePointer(
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.28),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // "Live" / status chip.
                Positioned(
                  top: 10,
                  left: 12,
                  child: _LiveChip(active: latest != null),
                ),

                // Expand icon → full history map.
                Positioned(
                  top: 8,
                  right: 8,
                  child: _ExpandButton(onTap: () => _openDetail(context)),
                ),
              ],
            ),
          ),

          // ---- Details footer --------------------------------------------
          InkWell(
            onTap: () => _openDetail(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _Footer(vm: vm, latest: latest, childName: childName),
            ),
          ),
        ],
      ),
    );
  }
}

/// The map itself, or a placeholder while there's no fix yet.
class _MapBody extends StatefulWidget {
  final LocationViewModel vm;
  final ChildLocation? latest;
  final bool permissionDenied;

  const _MapBody({
    required this.vm,
    required this.latest,
    this.permissionDenied = false,
  });

  @override
  State<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends State<_MapBody> {
  BitmapDescriptor? _personIcon;
  GoogleMapController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_personIcon == null) {
      PersonMarker.icon(context).then((b) {
        if (mounted) setState(() => _personIcon = b);
      });
    }
  }

  /// Whether [build] renders an actual [GoogleMap] for that widget, as opposed
  /// to one of the placeholders (loading, no fix yet, permission denied).
  bool _showsMap(_MapBody w) => !w.permissionDenied && w.latest != null;

  @override
  void didUpdateWidget(covariant _MapBody oldWidget) {
    super.didUpdateWidget(oldWidget);

    // This State outlives the map: swapping in a placeholder — which is what
    // the denied permission state does — disposes the GoogleMap while keeping
    // us alive, and the controller it handed us dies with it. Driving that
    // controller afterwards throws a use-after-disposed StateError, so drop it
    // and wait for the next onMapCreated.
    if (!_showsMap(widget) || !_showsMap(oldWidget)) {
      _controller = null;
      return;
    }

    final now = widget.latest!;
    final before = oldWidget.latest;
    final moved =
        before == null ||
        before.latitude != now.latitude ||
        before.longitude != now.longitude;
    if (!moved) return;

    // `initialCameraPosition` is only honoured when the map is first created,
    // so a fix arriving while the card is on screen would move the marker but
    // leave the camera behind — eventually off-frame. Follow it instead.
    // moveCamera, not animateCamera: lite mode doesn't run camera animations.
    _controller?.moveCamera(
      CameraUpdate.newLatLng(LatLng(now.latitude, now.longitude)),
    );
  }

  @override
  void dispose() {
    // The GoogleMap disposes its own controller when it leaves the tree, so
    // only release one we are still holding for a live map.
    if (_showsMap(widget)) _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final latest = widget.latest;

    if (widget.permissionDenied) {
      return Container(
        color: const Color(0xFFEAF1F4),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_rounded,
              color: AppColors.alert,
              size: 30,
            ),
            const SizedBox(height: 8),
            const Text(
              'Location permission not granted',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ask your child to allow Location in the Vigil Child app.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (latest == null) {
      if (vm.loading) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(color: Colors.white),
        );
      }
      return Container(
        color: const Color(0xFFEAF1F4),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              vm.error != null
                  ? Icons.location_off_rounded
                  : Icons.location_searching_rounded,
              color: AppColors.textSecondary,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              vm.error ?? 'No location yet',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final point = LatLng(latest.latitude, latest.longitude);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: point, zoom: 15),
      onMapCreated: (c) => _controller = c,
      markers: {
        Marker(
          markerId: const MarkerId('latest'),
          position: point,
          anchor: const Offset(0.5, 1.0),
          icon: _personIcon ?? BitmapDescriptor.defaultMarker,
        ),
      },
      // Preview only — the full detail map handles interaction. Lite mode keeps
      // the card a cheap static snapshot on Android.
      liteModeEnabled: true,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      scrollGesturesEnabled: false,
      zoomGesturesEnabled: false,
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: false,
    );
  }
}

class _Footer extends StatelessWidget {
  final LocationViewModel vm;
  final ChildLocation? latest;
  final String? childName;

  const _Footer({required this.vm, required this.latest, this.childName});

  @override
  Widget build(BuildContext context) {
    final title = (childName == null || childName!.trim().isEmpty)
        ? 'Live Location'
        : "${childName!.trim()}'s Location";

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.location_on_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                latest?.address.isNotEmpty == true
                    ? latest!.address
                    : (vm.loading ? 'Locating…' : 'Tap to view location'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Details',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ],
        ),
      ],
    );
  }
}

class _LiveChip extends StatelessWidget {
  final bool active;
  const _LiveChip({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Live' : 'Offline',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExpandButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(
            Icons.open_in_full_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
