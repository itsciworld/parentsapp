import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';
import 'package:vigil_parents_app/features/home/presentation/view_model/home_viewmodel.dart';
import 'package:vigil_parents_app/features/home/widgets/activity_summery.dart';
import 'package:vigil_parents_app/features/home/widgets/ai_foundation.dart';
import 'package:vigil_parents_app/features/home/widgets/child_card.dart';
import 'package:vigil_parents_app/features/home/widgets/feature_grid.dart';
import 'package:vigil_parents_app/features/home/widgets/home_Appbar.dart';
import 'package:vigil_parents_app/features/home/widgets/home_bottom.dart';

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

      bottomNavigationBar: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => HomeBottomNav(
          currentIndex: _vm.bottomNavIndex,
          onTap: _vm.onBottomNavTapped,
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
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

    return RefreshIndicator(
      onRefresh: vm.refresh,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
    );
  }
}

/// ----------------------------------------------------------------------------
/// Loading state
/// ----------------------------------------------------------------------------
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    // ✅ FIX 7: SafeArea wrap karo loading view mein bhi
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.headerTop, AppColors.headerBottom],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Loading dashboard…',
                style: TextStyle(color: AppColors.textOnDarkMuted),
              ),
            ],
          ),
        ),
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
