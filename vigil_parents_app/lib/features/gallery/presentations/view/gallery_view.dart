import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/components/app_bottom_nav.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/components/app_shimmer.dart';
import 'package:vigil_parents_app/features/gallery/presentations/view_model/gallery_viewmodel.dart';
import 'package:vigil_parents_app/features/gallery/presentations/widgets/gallery_photo_grid.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(galleryViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const AppBottomNav(),
      body: state.when(
        data: (vm) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppHeader(
                    showBack: true,
                    // actionIcon: Icons.settings,
                    onActionTap: () {},
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        GalleryHeader(child: vm.child),

                        const SizedBox(height: 20),

                        GalleryStatsCard(stats: vm.stats),

                        const SizedBox(height: 24),

                        RecentPhotosSection(photos: vm.recentPhotos),

                        const SizedBox(height: 24),

                        const Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 16),

                        GalleryPhotoGrid(photos: vm.todayPhotos),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        error: (_, _) => const Center(child: Text('Error')),
        loading: () => SafeArea(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppHeader(showBack: true, onActionTap: () {}),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(height: 90, radius: 16),
                      SizedBox(height: 20),
                      ShimmerBox(height: 70, radius: 16),
                      SizedBox(height: 24),
                      ShimmerBox(width: 120, height: 18),
                      SizedBox(height: 16),
                      GridShimmer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
