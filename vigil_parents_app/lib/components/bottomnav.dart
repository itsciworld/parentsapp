import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  USAGE — bas itna karo apni kisi bhi file mein:
//
//  AppBottomNav(
//    screens: [HomeScreen(), ReportScreen(), DeviceScreen(), SettingsScreen()],
//  )
//
//  Optional — kisi specific tab pe open karna ho:
//  AppBottomNav(
//    screens: [...],
//    initialIndex: 2,   // Device tab se shuru hoga
//  )
// ─────────────────────────────────────────────────────────────────────────────

class AppBottomNav extends StatefulWidget {
  /// Screens in order: [Home, Report, Device, Settings]
  final List<Widget> screens;

  /// Optional: konse tab pe start karna hai (default = 0 = Home)
  final int initialIndex;

  const AppBottomNav({super.key, required this.screens, this.initialIndex = 0})
    : assert(
        screens.length == 4,
        'Exactly 4 screens required: Home, Report, Device, Settings',
      );

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav>
    with TickerProviderStateMixin {
  late int _currentIndex;

  // ── Nav items config ──────────────────────────────────────────────────────
  static const _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.bar_chart_rounded, label: 'Report'),
    _NavItem(icon: Icons.devices_rounded, label: 'Device'),
    _NavItem(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  // ── Animation ─────────────────────────────────────────────────────────────
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnims;

  // ── Colors ────────────────────────────────────────────────────────────────
  static const _activeColor = Color(0xFF6C63FF);
  static const _inactiveColor = Color(0xFFB0B0C3);
  static const _bgColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _controllers = List.generate(
      _items.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
        value: i == _currentIndex ? 1.0 : 0.0,
      ),
    );

    _scaleAnims = _controllers
        .map(
          (c) => Tween<double>(
            begin: 1.0,
            end: 1.25,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack)),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTap(int index) {
    if (index == _currentIndex) return; // already on this tab → kuch nahi
    _controllers[_currentIndex].reverse();
    _controllers[index].forward();
    setState(() => _currentIndex = index);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack — sab screens alive rahenge, state preserve hoga
      body: IndexedStack(index: _currentIndex, children: widget.screens),
      bottomNavigationBar: _buildBar(),
    );
  }

  Widget _buildBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isActive = index == _currentIndex;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTap(index),
                  child: AnimatedBuilder(
                    animation: _controllers[index],
                    builder: (_, _) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ── Pill + Icon ──────────────────────────────────
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? _activeColor.withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ScaleTransition(
                            scale: _scaleAnims[index],
                            child: Icon(
                              item.icon,
                              size: 24,
                              color: isActive ? _activeColor : _inactiveColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // ── Label ────────────────────────────────────────
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isActive ? _activeColor : _inactiveColor,
                          ),
                          child: Text(item.label),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Internal data model (private) ─────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
