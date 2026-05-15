import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';
import 'package:vigil_parents_app/features/home/widgets/omman_widgets.dart';

/// "Live Location" card: details on the left, a stylised map preview on the
/// right with the child marker centered in a green geofence ring.
///
/// REPLACE-LATER: [_MapPreview] is a painted placeholder. Swap it with your
/// real map widget (google_maps_flutter / mapbox_maps_flutter) once the API is
/// available.
class LiveLocationCard extends StatelessWidget {
  final LiveLocation location;
  final String childAvatarUrl;
  final VoidCallback onViewOnMap;

  const LiveLocationCard({
    super.key,
    required this.location,
    required this.childAvatarUrl,
    required this.onViewOnMap,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: textual details ------------------------------------------
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              location.label,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 5),
                            if (location.isLive)
                              const StatusPill(
                                label: 'Live',
                                color: AppColors.primaryLight,
                                textColor: AppColors.primary,
                                withDot: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          location.address,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.gps_fixed_rounded,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              location.accuracy,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ViewOnMapButton(onTap: onViewOnMap),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Right: map preview ---------------------------------------------
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _MapPreview(childAvatarUrl: childAvatarUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewOnMapButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewOnMapButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View on Map',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.north_east_rounded, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painted stand-in for the real map. Shows a soft map-ish background, a green
/// geofence ring, and the child's avatar pin at the center.
class _MapPreview extends StatelessWidget {
  final String childAvatarUrl;
  const _MapPreview({required this.childAvatarUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base "map" gradient + grid
          CustomPaint(painter: _MapBackgroundPainter()),
          // Geofence ring
          Center(
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mapGreenZone,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          // Child marker pin
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: NetworkImage(childAvatarUrl),
                    onBackgroundImageError: (_, _) {},
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -4),
                  child: const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          // "Connaught Place" label chip
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'CONNAUGHT PLACE',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a simple light "map" texture with a few road lines.
class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEDEFF0), Color(0xFFE3E8E6)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // A couple of diagonal "roads".
    canvas.drawLine(
      Offset(0, size.height * 0.7),
      Offset(size.width, size.height * 0.3),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.7, size.height),
      road..strokeWidth = 4,
    );

    final park = Paint()..color = const Color(0xFFD4E6D0);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.8), 26, park);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
