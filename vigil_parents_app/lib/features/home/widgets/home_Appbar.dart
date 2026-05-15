import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/core/appimages/app_images.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';
import 'package:vigil_parents_app/features/home/widgets/omman_widgets.dart';

/// The very top bar: hamburger, VIGIL logo/brand, notification bell, parent chip.
///
/// REPLACE-LATER: the logo here is built with an [Icon] + text. Swap the
/// `_LogoMark` widget with your real asset, e.g.:
///   Image.asset('assets/images/vigil_logo.png', height: 36)
class HomeAppBar extends StatelessWidget {
  final ParentProfile parent;
  final int notificationCount;
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationsTap;

  const HomeAppBar({
    super.key,
    required this.parent,
    required this.notificationCount,
    required this.onMenuTap,
    required this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Hamburger -----------------------------------------------------------
        // _CircleIconButton(
        //   icon: Icons.menu_rounded,
        //   onTap: onMenuTap,
        //   iconColor: AppColors.textOnDark,
        // ),
        const SizedBox(width: 4),

        // Brand / logo --------------------------------------------------------
        const _LogoMark(),
        const Spacer(),

        // Notifications -------------------------------------------------------
        Stack(
          clipBehavior: Clip.none,
          children: [
            _CircleIconButton(
              icon: Icons.notifications_none_rounded,
              onTap: onNotificationsTap,
              iconColor: AppColors.textOnDark,
            ),
            if (notificationCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: CountBadge(count: notificationCount),
              ),
          ],
        ),
        const SizedBox(width: 4),

        // Parent chip ---------------------------------------------------------
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary,
                child: Text(
                  parent.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                parent.name,
                style: TextStyle(color: AppColors.textOnDark, fontSize: 13),
              ),
              // const Icon(
              //   Icons.keyboard_arrow_down_rounded,
              //   color: AppColors.textOnDark,
              //   size: 18,
              // ),
            ],
          ),
        ),
      ],
    );
  }
}

/// VIGIL brand lockup. REPLACE-LATER with your logo asset.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Shield mark
        Container(
          width: 104,
          height: 68,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Image.asset(AppImages.lsogo),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Text(
            //   'VIGIL',
            //   style: TextStyle(
            //     color: AppColors.textOnDark,
            //     letterSpacing: 2,
            //     fontSize: 20,
            //   ),
            // ),
            // Text(
            //   'PARENTAL MONITORING SYSTEM',
            //   style: TextStyle(
            //     color: AppColors.textOnDarkMuted,
            //     fontSize: 7,
            //     letterSpacing: 1,
            //   ),
            // ),
          ],
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: iconColor, size: 26),
        ),
      ),
    );
  }
}
