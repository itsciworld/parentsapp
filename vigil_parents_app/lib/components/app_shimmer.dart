import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';

/// Shared shimmer building blocks used for loading states across the app.
///
/// Wrap any tree of [ShimmerBox]es in [AppShimmer] to get the animated sweep.
/// For the common "list of cards" and "calendar + list" loaders use the ready
/// made [ListShimmer] / [EventsShimmer] / [GalleryShimmer] helpers.

/// Animated shimmer wrapper with the app's grey palette.
class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: child,
    );
  }
}

/// A single rounded placeholder block. Must sit inside an [AppShimmer].
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// One card-shaped skeleton: leading circle + two text lines + trailing chip.
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const ShimmerBox(width: 46, height: 46, radius: 23),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 150, height: 13),
                SizedBox(height: 9),
                ShimmerBox(width: 90, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const ShimmerBox(width: 40, height: 12),
        ],
      ),
    );
  }
}

/// A vertical list of shimmering card skeletons — for SMS / Calls / Contacts.
class ListShimmer extends StatelessWidget {
  final int items;
  const ListShimmer({super.key, this.items = 7});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => const _CardSkeleton(),
      ),
    );
  }
}

/// Calendar block + a few list cards — for the Events screen.
class EventsShimmer extends StatelessWidget {
  const EventsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          const ShimmerBox(height: 360, radius: 18),
          const SizedBox(height: 16),
          const ShimmerBox(width: 140, height: 16),
          const SizedBox(height: 14),
          for (var i = 0; i < 4; i++) ...[
            const _CardSkeleton(),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// A grid of square tile skeletons — for the Gallery screen.
class GridShimmer extends StatelessWidget {
  final int items;
  final int crossAxisCount;
  const GridShimmer({super.key, this.items = 9, this.crossAxisCount = 3});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (_, _) => const ShimmerBox(height: 100, radius: 12),
      ),
    );
  }
}
