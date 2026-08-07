import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/app_usage/presentation/widgets/app_icon_avatar.dart';
import 'package:vigil_parents_app/features/social_apps/presentation/view/social_screen_view.dart';
import 'package:vigil_parents_app/features/social_apps/presentation/view_model/social_screen_viewmodel.dart';

/// Home card that surfaces captured social-app chats. Shows the logos of the
/// apps we have messages for (or a default set as a teaser) and opens the full
/// [SocialScreenView] on tap.
class SocialAppsCard extends ConsumerWidget {
  const SocialAppsCard({super.key});

  /// The social apps the card always previews, so every brand logo is shown
  /// regardless of which apps currently have captured data. (appName, package)
  static const List<(String, String)> _socialApps = [
    ('WhatsApp', 'com.whatsapp'),
    ('Instagram', 'com.instagram.android'),
    ('Snapchat', 'com.snapchat.android'),
    ('Facebook', 'com.facebook.katana'),
  ];

  void _open(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => const SocialScreenView(),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(socialScreenViewModelProvider);

    final hasData = vm.apps.isNotEmpty;
    // Always show every social app's logo, regardless of captured data.
    const logos = _socialApps;
    final subtitle = hasData
        ? '${vm.totalMessages} message${vm.totalMessages == 1 ? '' : 's'} · '
              '${vm.apps.length} app${vm.apps.length == 1 ? '' : 's'}'
        : 'Tap to view captured chats';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.purpleIcon,
                          Color.lerp(
                            AppColors.purpleIcon,
                            AppColors.indigoIcon,
                            0.6,
                          )!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.purpleIcon.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.forum_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Social Apps',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.purpleIcon.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.purpleIcon,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // All app logos, wrapping to a new line if they don't fit.
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final logo in logos)
                    AppIconAvatar(
                      appName: logo.$1,
                      packageName: logo.$2,
                      size: 42,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
