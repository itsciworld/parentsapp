import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';

/// A map pin. The [latest] (most recent) fix pulses and uses a person icon;
/// older history points render as smaller dots.
class LocationPin extends StatefulWidget {
  final bool latest;
  final bool selected;
  final VoidCallback? onTap;

  const LocationPin({
    super.key,
    this.latest = false,
    this.selected = false,
    this.onTap,
  });

  @override
  State<LocationPin> createState() => _LocationPinState();
}

class _LocationPinState extends State<LocationPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.latest) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant LocationPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.latest && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.latest && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.latest) {
      // History dot.
      return GestureDetector(
        onTap: widget.onTap,
        child: Center(
          child: Container(
            width: widget.selected ? 20 : 14,
            height: widget.selected ? 20 : 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.blueIcon.withValues(alpha: 0.9),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blueIcon.withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Latest fix — pulsing person pin.
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding pulse ring.
              Container(
                width: 30 + t * 34,
                height: 30 + t * 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: (1 - t) * 0.28),
                ),
              ),
              child!,
            ],
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_pin_circle_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -4),
              child: const Icon(
                Icons.arrow_drop_down_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
