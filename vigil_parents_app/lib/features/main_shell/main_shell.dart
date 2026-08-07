import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/components/bottom_bar.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/ai_insights/presentation/view/ai_insights_view.dart';
import 'package:vigil_parents_app/features/ai_insights/presentation/view_model/ai_insights_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/view/child_view.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/home/presentation/view/home_view.dart';
import 'package:vigil_parents_app/features/main_shell/shell_tabs.dart';
import 'package:vigil_parents_app/features/profile/presentation/view/profile_view.dart';

class MainShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late int _currentIndex = widget.initialIndex;

  static const int _aiTabIndex = ShellTabs.aiInsights;
  static const int _profileTabIndex = ShellTabs.profile;

  static const _navItems = <CustomNavItem>[
    CustomNavItem(icon: Icons.home_rounded, label: 'Home'),
    CustomNavItem(icon: Icons.child_care_rounded, label: 'Child'),
    CustomNavItem(icon: Icons.auto_awesome_rounded, label: 'AI Insights'),
    CustomNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  DateTime? _lastBackPressed;

  /// Tabs are built lazily: a page is only created the first time it is
  /// opened, so its `initState` (and first API call) runs when the user
  /// actually lands on the tab instead of at app start.
  late final Set<int> _visitedTabs = <int>{widget.initialIndex};

  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != ShellTabs.home) {
      // Publish the starting tab without touching a provider inside build.
      Future.microtask(() {
        if (!mounted) return;
        ref.read(visibleTabProvider.notifier).state = widget.initialIndex;
      });
    }
    if (_currentIndex == _aiTabIndex) {
      Future.microtask(_loadAiInsights);
    }
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    _openTab(index);
  }

  /// Switches to [index], building the page on its first visit and announcing
  /// the change so the page can refresh itself (see [visibleTabProvider]).
  void _openTab(int index) {
    _visitedTabs.add(index);
    setState(() => _currentIndex = index);
    ref.read(visibleTabProvider.notifier).state = index;
    // AI Insights has no background job and the view doesn't fetch on its own,
    // so the shell kicks off the analysis whenever the tab is opened.
    if (index == _aiTabIndex) _loadAiInsights();
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
    if (_currentIndex != ShellTabs.home) {
      _openTab(ShellTabs.home);
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

  Widget _pageFor(int index) {
    switch (index) {
      case ShellTabs.home:
        return HomeScreen(onProfileTap: () => _onTabSelected(_profileTabIndex));
      case ShellTabs.child:
        return const ChildView();
      case _aiTabIndex:
        return const AiInsightsView();
      default:
        return const ProfileView();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      for (var i = 0; i < _navItems.length; i++)
        if (_visitedTabs.contains(i)) _pageFor(i) else const SizedBox.shrink(),
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
