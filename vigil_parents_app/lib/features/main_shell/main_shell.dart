import 'package:flutter/material.dart';
import 'package:vigil_parents_app/components/bottom_bar.dart';
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

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onProfileTap: () => _onTabSelected(2)),
      const ChildView(),
      const ProfileView(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTabSelected: _onTabSelected,
        items: _navItems,
      ),
    );
  }
}
