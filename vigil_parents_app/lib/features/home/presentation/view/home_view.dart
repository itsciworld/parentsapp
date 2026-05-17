import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/components/bottomnav.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';
import 'package:vigil_parents_app/features/home/presentation/view_model/home_viewmodel.dart';
import 'package:vigil_parents_app/features/home/widgets/activity_summery.dart';
import 'package:vigil_parents_app/features/home/widgets/ai_foundation.dart';
import 'package:vigil_parents_app/features/home/widgets/child_card.dart';
import 'package:vigil_parents_app/features/home/widgets/feature_grid.dart';
import 'package:vigil_parents_app/features/home/widgets/home_Appbar.dart';
import 'package:vigil_parents_app/features/home/widgets/home_bottom.dart';
import 'package:vigil_parents_app/features/home/widgets/live_location.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = HomeViewModel();
    _vm.init();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,

      // bottomNavigationBar: ListenableBuilder(
      //   listenable: _vm,
      //   builder: (context, _) => HomeBottomNav(
      //     currentIndex: _vm.bottomNavIndex,
      //     onTap: _vm.onBottomNavTapped,
      //   ),
      // ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          if (_vm.isLoading) return const _LoadingView();
          if (_vm.hasError) {
            return _ErrorView(
              message: _vm.errorMessage ?? 'Something went wrong',
              onRetry: _vm.refresh,
            );
          }
          return _LoadedView(vm: _vm, data: _vm.data!);
        },
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Loaded state
/// ----------------------------------------------------------------------------
class _LoadedView extends StatelessWidget {
  final HomeViewModel vm;
  final HomeDashboardData data;

  const _LoadedView({required this.vm, required this.data});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // transparent status bar
        statusBarIconBrightness: Brightness.light, // 🔥 WHITE icons
        statusBarBrightness: Brightness.dark, // iOS support
      ),
      child: RefreshIndicator(
        onRefresh: vm.refresh,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // AppHeader(showBack: false),
              // ---- Dark gradient header --------------------------------
              Stack(
                children: [
                  // Header background
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.headerTop, AppColors.headerBottom],
                      ),
                    ),
                    // ✅ Bottom padding extra rakha taaki Stack ka
                    // white body uske neeche se nikal sake
                    padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 36),
                    child: Column(
                      children: [
                        HomeAppBar(
                          parent: data.parent,
                          notificationCount: data.notificationCount,
                          onMenuTap: () {},
                          onNotificationsTap: vm.onNotificationsTapped,
                        ),
                        const SizedBox(height: 16),
                        ChildHeaderCard(
                          child: data.child,
                          indicators: data.statusIndicators,
                        ),
                      ],
                    ),
                  ),

                  // ✅ White rounded top — Positioned nahi, sirf
                  // Column ke andar last child ki tarah rakho
                  // taaki Stack ki height sahi calculate ho
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.scaffold,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ---- White body (Stack ke baad, seamless connect hoga) ----
              Container(
                width: double.infinity,
                color: AppColors.scaffold,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FeatureGrid(
                      features: data.features,
                      onTap: (tile) {
                        vm.onFeatureTapped(context, tile);
                      },
                    ),
                    // const SizedBox(height: 16),
                    // LiveLocationCard(
                    //   location: data.location,
                    //   childAvatarUrl: data.child.avatarUrl,
                    //   onViewOnMap: vm.onViewOnMap,
                    // ),
                    const SizedBox(height: 16),
                    ActivitySummaryCard(
                      activity: data.activity,
                      onViewAllAlerts: vm.onViewAllAlerts,
                    ),
                    // const SizedBox(height: 16),
                    // AiInsightCard(
                    //   insight: data.aiInsight,
                    //   onViewInsight: vm.onViewInsight,
                    // ),
                    const SizedBox(height: 16),
                    FoundationCard(
                      info: data.foundation,
                      onKnowMore: vm.onKnowMoreFoundation,
                    ),
                    SizedBox(height: bottomPadding + 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 🔹 Header skeleton
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.white),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _box(width: 40, height: 40, radius: 20),
                        const SizedBox(width: 12),
                        Expanded(child: _box(height: 16)),
                        const SizedBox(width: 12),
                        _box(width: 30, height: 30, radius: 8),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _box(height: 90, radius: 16), // child card
                  ],
                ),
              ),

              // 🔹 Body skeleton
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Feature grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.4,
                          ),
                      itemBuilder: (_, __) => _box(radius: 16),
                    ),

                    const SizedBox(height: 16),

                    // Activity card
                    _box(height: 120, radius: 16),

                    const SizedBox(height: 16),

                    // Foundation card
                    _box(height: 100, radius: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box({
    double width = double.infinity,
    double height = 16,
    double radius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Error state
/// ----------------------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
