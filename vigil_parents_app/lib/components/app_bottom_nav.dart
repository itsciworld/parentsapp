import 'package:flutter/material.dart';
import 'package:vigil_parents_app/components/bottom_bar.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/core/routing/routes.dart';

/// The app-wide bottom navigation bar (Home / Child / AI Insights / Profile).
///
/// On the shell tabs the [MainShell] manages selection itself. On feature
/// screens (SMS, Calls, Contacts, ...) drop in this widget — tapping an item
/// returns to the shell on that tab. Pass [currentIndex] = -1 (default) on
/// feature screens so no tab is highlighted.
///
/// The item order MUST stay in sync with [MainShell]'s nav items — the index
/// is forwarded as the shell's `initialIndex`.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, this.currentIndex = -1});

  static const items = <CustomNavItem>[
    CustomNavItem(icon: Icons.home_rounded, label: 'Home'),
    CustomNavItem(icon: Icons.child_care_rounded, label: 'Child'),
    CustomNavItem(icon: Icons.auto_awesome_rounded, label: 'AI Insights'),
    CustomNavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  void _go(BuildContext context, int index) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutesName.homeView,
      (route) => false,
      arguments: {'initialIndex': index},
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomBottomNavBar(
      currentIndex: currentIndex,
      onTabSelected: (i) => _go(context, i),
      items: items,
      activeColor: AppColors.primary,
    );
  }
}
