import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appimages/app_images.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool showBack;
  final VoidCallback? onBackTap;
  final IconData? actionIcon;
  final VoidCallback? onActionTap;
  final String logoAsset;
  final Color backgroundColor;
  final Color iconColor;

  const AppHeader({
    super.key,
    this.showBack = true,
    this.onBackTap,
    this.actionIcon,
    this.onActionTap,
    this.logoAsset = AppImages.logo1,
    this.backgroundColor = Colors.white,
    this.iconColor = const Color(0xFF1A237E),
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        children: [
          // ── Left: Back Button ────────────────────────────────────────
          _SideSlot(
            child: showBack
                ? _IconBtn(
                    icon: Icons.arrow_back,
                    color: iconColor,
                    onTap: onBackTap ?? () => Navigator.maybePop(context),
                  )
                : null,
          ),

          // ── Center: Logo + VIGIL + tagline ───────────────────────────
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Shield logo
                  Image.asset(logoAsset, height: 44, fit: BoxFit.cover),

                  // VIGIL + tagline
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // VIGIL — blue → green gradient
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFF1A237E), // deep blue
                            Color(0xFF2E7D32), // deep green
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(Rect.fromLTWH(0, 0, 80, bounds.height)),
                        child: const Text(
                          'VIGIL',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                            height: 1,
                          ),
                        ),
                      ),

                      // Tagline
                      const Text(
                        'Watch Smart. Protect Better',
                        style: TextStyle(
                          fontSize: 5.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A237E),
                          letterSpacing: 0.3,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Right: Optional Action Icon ──────────────────────────────
          _SideSlot(
            child: actionIcon != null
                ? _IconBtn(
                    icon: actionIcon!,
                    color: iconColor,
                    onTap: onActionTap ?? () {},
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _SideSlot extends StatelessWidget {
  final Widget? child;
  const _SideSlot({this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 48, child: child ?? const SizedBox.shrink());
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
