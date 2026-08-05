import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';

/// Shown when the account has no linked/registered child yet. It tells the
/// parent what to do: register a child from the Vigil Child app first.
///
/// Pass [dark] = true on the dark gradient header.
class NoChildLinkedView extends StatelessWidget {
  final bool dark;
  final VoidCallback? onRefresh;
  final bool refreshing;

  const NoChildLinkedView({
    super.key,
    this.dark = false,
    this.onRefresh,
    this.refreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color titleColor = dark
        ? AppColors.textOnDark
        : AppColors.textPrimary;
    final Color bodyColor = dark
        ? AppColors.textOnDarkMuted
        : AppColors.textSecondary;
    final Color cardColor = dark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.surface;
    final Color borderColor = dark
        ? Colors.white.withValues(alpha: 0.16)
        : AppColors.cardBorder;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: dark ? 0.18 : 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phonelink_erase_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No child linked yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Install the Vigil Child app on your child\'s phone and register a '
            'child there first. Once linked, come back here to start monitoring.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.45, color: bodyColor),
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: refreshing ? null : onRefresh,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(refreshing ? 'Checking...' : 'Refresh'),
            ),
          ],
        ],
      ),
    );
  }
}
