import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/components/bottom_bar.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/features/ai_insights/presentation/view/ai_insights_view.dart';
import 'package:vigil_parents_app/features/ai_insights/presentation/view_model/ai_insights_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/view/child_view.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/home/presentation/view/home_view.dart';
import 'package:vigil_parents_app/features/profile/presentation/view/profile_view.dart';

class MainShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late int _currentIndex = widget.initialIndex;

  static const int _aiTabIndex = 2;
  static const int _profileTabIndex = 3;

  static const _navItems = <CustomNavItem>[
    CustomNavItem(icon: Icons.home_rounded, label: 'Home'),
    CustomNavItem(icon: Icons.child_care_rounded, label: 'Child'),
    // AI Insights is gated until the paid version — tapping it shows a toast
    // instead of switching to the tab.
    CustomNavItem(
      icon: Icons.auto_awesome_rounded,
      label: 'AI Insights',
      locked: true,
    ),
    CustomNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    if (_currentIndex == _aiTabIndex) {
      Future.microtask(_loadAiInsights);
    }
  }

  void _onTabSelected(int index) {
    // AI Insights is locked until the paid version — show a toast and stay put
    // instead of opening the tab.
    if (index == _aiTabIndex) {
      showAppToast(
        context: context,
        title: 'Premium Feature',
        subtitle: 'AI Insights is coming in the paid version.',
        type: ToastType.info,
        icon: Icons.lock_rounded,
      );
      return;
    }
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  /// Resolves the selected child and runs today's AI analysis. The shimmer
  /// loader only shows when there is nothing on screen yet (first visit or
  /// child switch); re-visits refresh silently.
  Future<void> _loadAiInsights() async {
    await ref.read(selectedChildProvider).load();
    if (!mounted) return;
    final id = ref.read(selectedChildProvider).selectedId;
    if (id == null) return;
    final vm = ref.read(aiInsightsViewModelProvider);
    vm.load(id, showLoader: vm.childId != id || vm.data == null);
  }

  /// Android back behavior:
  /// - On a non-Home tab → jump back to the Home tab.
  /// - On the Home tab → require two presses within 2s to exit the app.
  void _handleBack() {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return;
    }

    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onProfileTap: () => _onTabSelected(_profileTabIndex)),
      const ChildView(),
      const AiInsightsView(),
      const ProfileView(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: pages),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
          items: _navItems,
          activeColor: AppColors.primary,
        ),
      ),
    );
  }
}
