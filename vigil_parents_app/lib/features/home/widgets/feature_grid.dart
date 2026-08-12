import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';

class FeatureGrid extends StatelessWidget {
  final List<FeatureTile> features;
  final void Function(FeatureTile tile) onTap;

  const FeatureGrid({super.key, required this.features, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final tile = features[index];
        return _FeatureTileCard(
          tile: tile,
          onTap: () {
            if (tile.isLocked) {
              showAppToast(
                context: context,
                title: 'Premium Feature',
                subtitle: '${tile.title} is coming in the paid version.',
                type: ToastType.info,
                icon: Icons.lock_rounded,
              );
            } else {
              onTap(tile);
            }
          },
        );
      },
    );
  }
}

class _FeatureTileCard extends StatelessWidget {
  final FeatureTile tile;
  final VoidCallback onTap;

  const _FeatureTileCard({required this.tile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Main content ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon box
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tile.isLocked
                          ? Colors
                                .grey
                                .shade100 // 👈 locked = greyed out
                          : tile.iconBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      tile.icon,
                      color: tile.isLocked
                          ? Colors
                                .grey
                                .shade400 // 👈 greyed icon
                          : tile.iconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tile.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tile.isLocked
                          ? Colors
                                .grey
                                .shade400 // 👈 greyed text
                          : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tile.subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: tile.isLocked
                          ? Colors.grey.shade300
                          : Colors.black45,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── Badge (only if unlocked) ───────────────────────────
            if (tile.badgeCount != null && !tile.isLocked)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    // A child's message or contact history runs into the
                    // thousands, and the raw number would grow the pill wider
                    // than the tile it sits on.
                    tile.badgeCount! > 99 ? '99+' : '${tile.badgeCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // ── 🔒 Lock icon (top-right, only if locked) ──────────
            if (tile.isLocked)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
