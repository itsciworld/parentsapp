import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/components/app_bottom_nav.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/no_child_linked_view.dart';
import 'package:vigil_parents_app/features/gallery/models/media_model.dart';
import 'package:vigil_parents_app/features/gallery/presentations/view_model/gallery_viewmodel.dart';
import 'package:vigil_parents_app/features/gallery/presentations/widgets/gallery_photo_grid.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  Timer? _pollTimer;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      // Load the children list for the picker, then the media for the
      // currently selected child.
      await ref.read(selectedChildProvider).load();
      ref.read(galleryViewModelProvider).load();
    });

    // Refresh from the API every 10s while the screen is open.
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.read(galleryViewModelProvider).refresh();
    });

    // Infinite scroll — fetch the next page near the bottom.
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      ref.read(galleryViewModelProvider).loadMore();
    }
  }

  /// Reloads media for the newly-selected child. The dropdown persists the
  /// selection itself.
  void _onChildSelected(String childId) {
    ref.read(galleryViewModelProvider).reload();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(galleryViewModelProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final size = MediaQuery.of(context).size;

    final noChild = selectedChild.initialized && selectedChild.children.isEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              AppHeader(onActionTap: () {}),

              const SizedBox(height: 16),

              if (noChild)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: NoChildLinkedView(
                        refreshing: selectedChild.loading,
                        onRefresh: () =>
                            ref.read(selectedChildProvider).load(force: true),
                      ),
                    ),
                  ),
                )
              else ...[
                /// CHILD PICKER
                Row(
                  children: [
                    const Text(
                      'Media & Gallery',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      child: ChildSelectorDropdown(onChanged: _onChildSelected),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                /// FILTER TABS
                GalleryFilterTabs(
                  selected: vm.filter,
                  onChanged: (f) =>
                      ref.read(galleryViewModelProvider).setFilter(f),
                ),

                const SizedBox(height: 14),

                /// STATS
                GalleryStatsCard(
                  total: vm.total,
                  photos: vm.imageCount,
                  videos: vm.videoCount,
                ),

                const SizedBox(height: 14),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: vm.refresh,
                    color: AppColors.primary,
                    child: _buildBody(vm, size),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(GalleryViewModel vm, Size size) {
    // First load (or filter change) → shimmer grid.
    if (vm.loading && vm.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [GalleryGridShimmer()],
      );
    }

    // Error with nothing to show → retry message.
    if (vm.error != null && vm.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: size.height * 0.16),
          const Icon(Icons.cloud_off_rounded, size: 52, color: AppColors.alert),
          const SizedBox(height: 12),
          Center(
            child: Text(
              vm.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Pull down to retry',
              style: TextStyle(color: Colors.black38, fontSize: 12),
            ),
          ),
        ],
      );
    }

    // Loaded but empty.
    if (vm.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: size.height * 0.16),
          const Icon(
            Icons.photo_library_outlined,
            size: 52,
            color: Colors.black26,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              switch (vm.filter) {
                MediaFilter.image => 'No photos yet',
                MediaFilter.video => 'No videos yet',
                MediaFilter.all => 'No media yet',
              },
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        GalleryMediaGrid(items: vm.items),
        if (vm.loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
