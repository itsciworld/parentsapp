import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/child/models/child_permissions_model.dart';

/// Shown in place of a feature's content when the child has not granted the
/// permission that feeds it (`dataAccess` on
/// GET /api/children/{childId}/permissions).
///
/// Without this the screen renders an empty list, which reads as "there is
/// nothing here" or a bug — when in fact the parent has to ask the child to
/// turn the permission on.
class PermissionDeniedView extends StatelessWidget {
  final ChildFeature feature;

  /// The child's name, used to make the message concrete. Falls back to a
  /// generic wording when unknown.
  final String? childName;

  final VoidCallback? onRefresh;
  final bool refreshing;

  const PermissionDeniedView({
    super.key,
    required this.feature,
    this.childName,
    this.onRefresh,
    this.refreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = childName?.trim();
    final who = (name == null || name.isEmpty) ? 'Your child' : name;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.alert.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(feature.icon, color: AppColors.alert, size: 30),
          ),
          const SizedBox(height: 16),
          const Text(
            'Permission not granted',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$who has not allowed ${feature.label} access on their device, so '
            '${feature.what} cannot be shown here.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.scaffold,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ask $who to turn on ${feature.label} in the Vigil Child '
                    'app, then refresh this screen.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
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
              label: Text(refreshing ? 'Checking...' : 'Check again'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Scrollable wrapper so the denied card can sit inside an `Expanded` on the
/// feature screens and still work with a pull-to-refresh above it.
class PermissionDeniedBody extends StatelessWidget {
  final ChildFeature feature;
  final String? childName;
  final VoidCallback? onRefresh;
  final bool refreshing;

  const PermissionDeniedBody({
    super.key,
    required this.feature,
    this.childName,
    this.onRefresh,
    this.refreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: PermissionDeniedView(
        feature: feature,
        childName: childName,
        onRefresh: onRefresh,
        refreshing: refreshing,
      ),
    );
  }
}
