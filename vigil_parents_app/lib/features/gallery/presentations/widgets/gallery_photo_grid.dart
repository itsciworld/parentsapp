import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/gallery/models/media_model.dart';
import 'package:vigil_parents_app/features/gallery/presentations/widgets/media_viewer.dart';

/// =======================================================
/// FILTER TABS  (All / Photos / Videos)
/// =======================================================

class GalleryFilterTabs extends StatelessWidget {
  final MediaFilter selected;
  final ValueChanged<MediaFilter> onChanged;

  const GalleryFilterTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: MediaFilter.values.map((f) {
          final isActive = f == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(f),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      switch (f) {
                        MediaFilter.all => Icons.grid_view_rounded,
                        MediaFilter.image => Icons.photo_outlined,
                        MediaFilter.video => Icons.videocam_outlined,
                      },
                      size: 16,
                      color: isActive
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// =======================================================
/// STATS CARD  (totals for the active filter)
/// =======================================================

class GalleryStatsCard extends StatelessWidget {
  final int total;
  final int photos;
  final int videos;

  const GalleryStatsCard({
    super.key,
    required this.total,
    required this.photos,
    required this.videos,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            icon: Icons.perm_media_outlined,
            color: AppColors.indigoIcon,
            count: total,
            label: 'Total',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            icon: Icons.photo_outlined,
            color: AppColors.blueIcon,
            count: photos,
            label: 'Photos',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            icon: Icons.videocam_outlined,
            color: AppColors.orangeIcon,
            count: videos,
            label: 'Videos',
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final String label;

  const _StatBox({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================================================
/// MEDIA GRID
/// =======================================================

class GalleryMediaGrid extends StatelessWidget {
  final List<MediaItem> items;

  const GalleryMediaGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: .82,
      ),
      itemBuilder: (_, index) => MediaTile(
        item: items[index],
        onTap: () => MediaViewer.open(context, items, index),
      ),
    );
  }
}

/// A single media cell: thumbnail with a play overlay for videos, a favorite
/// badge, and the capture time. Uses [Image.network]'s loadingBuilder for a
/// shimmer placeholder and a graceful error fallback.
class MediaTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;

  const MediaTile({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Hero(
              tag: 'media_${item.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Thumbnail(item: item),

                    // Subtle bottom gradient so overlays stay readable.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.28),
                            ],
                            stops: const [0.6, 1],
                          ),
                        ),
                      ),
                    ),

                    // Play button for videos.
                    if (item.isVideo) const Center(child: _PlayBadge()),

                    // Favorite indicator.
                    if (item.isFavorite)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite,
                            size: 13,
                            color: AppColors.alert,
                          ),
                        ),
                      ),

                    // Duration chip for videos.
                    if (item.isVideo && item.formattedDuration.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.formattedDuration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.formattedTime.isNotEmpty
                ? item.formattedTime
                : item.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Network image with a shimmer placeholder while loading and an icon
/// fallback on error. Videos fall back to a dark tile (no inline thumbnail
/// available from the API).
class _Thumbnail extends StatelessWidget {
  final MediaItem item;

  const _Thumbnail({required this.item});

  @override
  Widget build(BuildContext context) {
    // Videos in this API don't ship a poster image, so render a styled
    // placeholder instead of attempting to load the .mp4 as an image.
    if (item.isVideo) {
      return Container(
        color: const Color(0xFF1A1D29),
        child: const Center(
          child: Icon(Icons.movie_outlined, color: Colors.white24, size: 40),
        ),
      );
    }

    return Image.network(
      item.url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _ShimmerBox();
      },
      errorBuilder: (context, error, stack) => Container(
        color: AppColors.scaffold,
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: AppColors.textSecondary,
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70, width: 1.5),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

/// =======================================================
/// SHIMMER PLACEHOLDERS
/// =======================================================

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE9ECF2),
      highlightColor: const Color(0xFFF6F8FB),
      child: Container(color: const Color(0xFFE9ECF2)),
    );
  }
}

/// Full grid of shimmer tiles shown while the first page loads.
class GalleryGridShimmer extends StatelessWidget {
  final int count;

  const GalleryGridShimmer({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: .82,
      ),
      itemBuilder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: const _ShimmerBox(),
            ),
          ),
          const SizedBox(height: 6),
          Shimmer.fromColors(
            baseColor: const Color(0xFFE9ECF2),
            highlightColor: const Color(0xFFF6F8FB),
            child: Container(
              width: 60,
              height: 11,
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECF2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
