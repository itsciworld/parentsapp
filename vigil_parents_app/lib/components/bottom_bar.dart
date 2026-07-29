import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  CustomNavItem — data model
// ─────────────────────────────────────────────
class CustomNavItem {
  final IconData icon;
  final String label;

  /// When true, a small lock badge is drawn on the icon. Tapping is still
  /// routed through [CustomBottomNavBar.onTabSelected] — the caller decides
  /// what a tap on a locked item does.
  final bool locked;

  const CustomNavItem({
    required this.icon,
    required this.label,
    this.locked = false,
  });
}

// ─────────────────────────────────────────────
//  CustomBottomNavBar — drop-in widget
//
//  Features:
//  • Animated scale + pill highlight on active tab
//  • Tap on already-active tab → nothing happens
//    (handle this in YOUR onTabSelected callback
//     by checking if index == currentIndex)
// ─────────────────────────────────────────────
class CustomBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final List<CustomNavItem> items;

  /// Active icon/label/pill color
  final Color activeColor;

  /// Inactive icon/label color
  final Color inactiveColor;

  /// Bar background color
  final Color backgroundColor;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.items,
    this.activeColor = const Color(0xFF6C63FF),
    this.inactiveColor = const Color(0xFFB0B0C3),
    this.backgroundColor = Colors.white,
  });

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.items.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
        value: i == widget.currentIndex ? 1.0 : 0.0,
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
  void didUpdateWidget(CustomBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _controllers[oldWidget.currentIndex].reverse();
      _controllers[widget.currentIndex].forward();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(widget.items.length, (index) {
              final item = widget.items[index];
              final isActive = index == widget.currentIndex;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onTabSelected(index),
                  child: AnimatedBuilder(
                    animation: _controllers[index],
                    builder: (context, _) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Pill + icon
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? widget.activeColor.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ScaleTransition(
                              scale: _scaleAnims[index],
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 24,
                                    color: isActive
                                        ? widget.activeColor
                                        : widget.inactiveColor,
                                  ),
                                  // Small lock badge for gated tabs.
                                  if (item.locked)
                                    Positioned(
                                      right: -6,
                                      top: -6,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: widget.backgroundColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.lock_rounded,
                                          size: 11,
                                          color: widget.inactiveColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Label
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isActive
                                  ? widget.activeColor
                                  : widget.inactiveColor,
                            ),
                            child: Text(item.label),
                          ),
                        ],
                      );
                    },
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
