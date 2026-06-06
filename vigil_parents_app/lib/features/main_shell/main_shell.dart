import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vigil_parents_app/components/bottom_bar.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/child/presentation/view/child_view.dart';
import 'package:vigil_parents_app/features/home/presentation/view/home_view.dart';
import 'package:vigil_parents_app/features/profile/presentation/view/profile_view.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex = widget.initialIndex;

  static const _navItems = <CustomNavItem>[
    CustomNavItem(icon: Icons.home_rounded, label: 'Home'),
    CustomNavItem(icon: Icons.child_care_rounded, label: 'Child'),
    CustomNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  DateTime? _lastBackPressed;

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
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
      HomeScreen(onProfileTap: () => _onTabSelected(2)),
      const ChildView(),
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
