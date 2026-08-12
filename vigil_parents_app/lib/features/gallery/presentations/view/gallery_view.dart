import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/core/services/background/sync_signals.dart';
import 'package:vigil_parents_app/core/utils/polling_screen.dart';
import 'package:vigil_parents_app/components/app_bottom_nav.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/child/models/child_permissions_model.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/child_permissions_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/no_child_linked_view.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/permission_denied_view.dart';
import 'package:vigil_parents_app/features/gallery/models/media_model.dart';
import 'package:vigil_parents_app/features/gallery/presentations/view_model/gallery_viewmodel.dart';
import 'package:vigil_parents_app/features/gallery/presentations/widgets/gallery_photo_grid.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen>
    with WidgetsBindingObserver, PollingScreen<GalleryScreen> {
  final _scrollController = ScrollController();

  @override
  Duration get pollInterval => const Duration(seconds: 10);

  @override
  String? get pollFeature => SyncFeature.media;

  @override
  void onPoll() => ref.read(galleryViewModelProvider).refresh();

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      // Load the children list for the picker, then the media for the
      // currently selected child.
      await ref.read(selectedChildProvider).load();
      if (!mounted) return;
      ref.read(galleryViewModelProvider).load();
      final id = ref.read(selectedChildProvider).selectedId;
      if (id != null) ref.read(childPermissionsProvider).ensureLoadedFor(id);
    });

    startPolling();

    // Infinite scroll — fetch the next page near the bottom.
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    stopPolling();
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
    ref.read(childPermissionsProvider).load(childId);
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(galleryViewModelProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final size = MediaQuery.of(context).size;

    final noChild = selectedChild.initialized && selectedChild.children.isEmpty;

    // Photo sharing is off on the child's device — no media will ever arrive
    // for this screen, so say that instead of showing an empty grid that reads
    // as "nothing captured yet".
    final permsVm = ref.watch(childPermissionsProvider);
    final denied = permsVm.isDenied(
      selectedChild.selectedId,
      ChildFeature.photos,
    );

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

                if (denied)
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => ref
                          .read(childPermissionsProvider)
                          .load(selectedChild.selectedId!),
                      child: PermissionDeniedBody(
                        feature: ChildFeature.photos,
                        childName: selectedChild.selected?.name,
                        refreshing: permsVm.loading,
                        onRefresh: () => ref
                            .read(childPermissionsProvider)
                            .load(selectedChild.selectedId!),
                      ),
                    ),
                  )
                else ...[
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
