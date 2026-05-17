import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';
import 'package:vigil_parents_app/features/home/widgets/omman_widgets.dart';

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
      // Removed IntrinsicHeight so the card scales to its content naturally
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: textual details ------------------------------------------
          Expanded(
            flex: 1, // Balanced flex ratio
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Keep column tight
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (location.isLive)
                        const StatusPill(
                          label: 'Live',
                          color: AppColors.primaryLight,
                          textColor: AppColors.primary,
                          withDot: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location.address,
                    maxLines: 2, // Allow max 2 lines, then truncate
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.gps_fixed_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        location.accuracy,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ViewOnMapButton(onTap: onViewOnMap),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Right: map preview ---------------------------------------------
          Expanded(
            flex: 1,
            // Constrain the map's height to keep the card compact
            child: SizedBox(
              height: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _MapPreview(childAvatarUrl: childAvatarUrl),
              ),
            ),
          ),
        ],
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
        // Greatly reduced padding to make the button proportional
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View Map', // Shortened text
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13, // Scaled down font size
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.north_east_rounded, color: Colors.white, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  final String childAvatarUrl;
  const _MapPreview({required this.childAvatarUrl});

  @override
  Widget build(BuildContext context) {
    // Inherits bounds from parent instead of using a hardcoded height
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base "map" gradient + grid
        CustomPaint(painter: _MapBackgroundPainter()),
        // Geofence ring (Responsive)
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Geofence size is now relative to the container width (65%)
              final size = constraints.maxWidth * 0.65;
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.mapGreenZone,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
              );
            },
          ),
        ),
        // Child marker pin
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(2), // Thinner padding
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 14, // Slightly smaller avatar
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: NetworkImage(childAvatarUrl),
                  onBackgroundImageError: (_, _) {},
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -3),
                child: const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        // "Connaught Place" label chip
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'CONNAUGHT PLACE',
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
      ..strokeWidth =
          5 // Slightly thinner lines
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height * 0.7),
      Offset(size.width, size.height * 0.3),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.7, size.height),
      road..strokeWidth = 3,
    );

    final park = Paint()..color = const Color(0xFFD4E6D0);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.8), 20, park);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
