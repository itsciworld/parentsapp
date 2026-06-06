import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/core/appColor/app_theme/app_gradient.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/core/routing/routes.dart';
import 'package:vigil_parents_app/features/auth/repo/auth_repo.dart';
import 'package:vigil_parents_app/features/child/models/child_permissions_model.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/child_permissions_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/profile/models/profile_model.dart';
import 'package:vigil_parents_app/globle_components/custom_button/custombutton.dart';
import 'package:vigil_parents_app/features/profile/presentation/view_model/profile_viewmodel.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      ref.read(profileViewModelProvider).loadProfile();
      // Load the selected child, then permissions for the active child.
      await ref.read(selectedChildProvider).load();
      final childId = ref.read(selectedChildProvider).selectedId;
      if (childId != null) {
        ref.read(childPermissionsProvider).load(childId);
      }
    });
  }

  /// Pull-to-refresh: reloads the profile and the child's permissions.
  Future<void> _refreshAll() async {
    await ref.read(profileViewModelProvider).refresh();
    await ref.read(selectedChildProvider).load(force: true);
    final childId = ref.read(selectedChildProvider).selectedId;
    if (childId != null) {
      await ref.read(childPermissionsProvider).load(childId);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(selectedChildProvider.select((vm) => vm.selectedId), (
      previousId,
      nextId,
    ) {
      if (nextId != null && nextId != previousId) {
        ref.read(childPermissionsProvider).load(nextId);
      }
    });

    final vm = ref.watch(profileViewModelProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final permsVm = ref.watch(childPermissionsProvider);

    if (selectedChild.selectedId != null &&
        permsVm.permissions == null &&
        !permsVm.loading) {
      ref.read(childPermissionsProvider).load(selectedChild.selectedId!);
    }

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: AppColors.headerTop,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AppColors.textOnDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textOnDark),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refreshAll,
        child: _buildBody(vm),
      ),
    );
  }

  Widget _buildBody(ProfileViewModel vm) {
    if (vm.isLoading && vm.profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.hasError && vm.profile == null) {
      return _ErrorState(
        message: vm.errorMessage ?? 'Something went wrong',
        onRetry: () => vm.loadProfile(),
      );
    }

    final profile = vm.profile;
    if (profile == null) {
      return const _ErrorState(
        message: 'No profile data available',
        onRetry: null,
      );
    }

    final selectedChild = ref.watch(selectedChildProvider);
    final permsVm = ref.watch(childPermissionsProvider);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _ProfileHeader(profile: profile),
        const SizedBox(height: 20),
        _InfoSection(
          title: 'Contact Information',
          icon: Icons.contacts_rounded,
          rows: [
            _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: profile.email,
            ),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Mobile',
              value: profile.mobile,
            ),
            _InfoRow(
              icon: Icons.phone_forwarded_outlined,
              label: 'Alternate Mobile',
              value: profile.alternateMobile,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InfoSection(
          title: 'Location',
          icon: Icons.location_on_outlined,
          rows: [
            _InfoRow(
              icon: Icons.public_rounded,
              label: 'Country',
              value: profile.country,
            ),
            _InfoRow(
              icon: Icons.location_city_rounded,
              label: 'City',
              value: profile.city,
            ),
            _InfoRow(
              icon: Icons.home_outlined,
              label: 'Address',
              value: profile.address,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InfoSection(
          title: 'Account',
          icon: Icons.shield_outlined,
          rows: [
            _InfoRow(
              icon: Icons.verified_user_outlined,
              label: 'Status',
              value: _capitalize(profile.status),
            ),
            _InfoRow(
              icon: Icons.app_registration_rounded,
              label: 'Registered Via',
              value: _capitalize(profile.registeredVia),
            ),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Member Since',
              value: _formatDate(profile.createdAt),
            ),
            _InfoRow(
              icon: Icons.login_rounded,
              label: 'Last Login',
              value: _formatDateTime(profile.lastLogin),
            ),
          ],
        ),
        if (selectedChild.selected != null) ...[
          const SizedBox(height: 16),
          _PermissionsSection(
            childName: selectedChild.selected!.name,
            permissions: permsVm.permissions,
            loading: permsVm.loading,
            error: permsVm.error,
          ),
        ],
        const SizedBox(height: 24),
        CustomButton(
          label: 'Log out',
          isLoading: _isLoggingOut,
          arrowIcon: false,
          gradient: AppGradients.danger,
          onTap: _confirmAndLogout,
        ),
      ],
    );
  }

  Future<void> _confirmAndLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Are you sure you want to log out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.alert),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);

    // Notify backend; local session is cleared inside logout() regardless.
    String? errorMessage;
    try {
      await AuthRepository().logout();
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
    }

    if (!mounted) return;
    setState(() => _isLoggingOut = false);

    if (errorMessage != null) {
      showAppToast(
        context: context,
        title: 'Logged out',
        subtitle: 'Signed out locally ($errorMessage)',
        type: ToastType.warning,
      );
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutesName.loginView, (route) => false);
  }
}

// ── Header card ───────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final ProfileModel profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final isActive = profile.status.toLowerCase() == 'active';

    final statusColor = isActive ? AppColors.online : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
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
        children: [
          // Avatar with a soft ring + verified badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight,
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    _initialsFor(profile.name),
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
              if (profile.isVerified)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: AppColors.online,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            profile.name.isEmpty ? 'Unnamed' : profile.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 21,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  isActive ? 'Active' : _capitalize(profile.status),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initialsFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

// ── Info section card ───────────────────────────────────────────────────────────
class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_InfoRow> rows;

  const _InfoSection({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    // Hide rows whose value is null/empty, and the whole section if nothing
    // is left to show.
    final visibleRows = rows.where((r) => r.value.trim().isNotEmpty).toList();
    if (visibleRows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < visibleRows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.cardBorder),
            visibleRows[i],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty ? '—' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  display,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Child permissions card ──────────────────────────────────────────────────────
class _PermissionsSection extends StatelessWidget {
  final String childName;
  final ChildPermissions? permissions;
  final bool loading;
  final String? error;

  const _PermissionsSection({
    required this.childName,
    required this.permissions,
    required this.loading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Child Permissions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            childName.trim().isEmpty
                ? 'Access this child has granted'
                : 'Access ${childName.trim()} has granted',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (permissions == null && loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    if (permissions == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          error ?? 'Couldn\'t load permissions',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }

    final items = permissions!.items;
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'No permissions available',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final color = item.granted ? AppColors.online : AppColors.textSecondary;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: item.granted
                ? AppColors.online.withValues(alpha: 0.14)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                size: 16,
                color: item.granted
                    ? AppColors.online
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: TextStyle(
                  color: item.granted
                      ? AppColors.online
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!item.granted) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Text(
                    'Off',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.alert),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Unable to load profile',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 18),
          Center(
            child: FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────
// These return an empty string for missing values so the row/section is hidden
// instead of showing a placeholder.
String _capitalize(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

const _months = [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDate(DateTime? date) {
  if (date == null) return '';
  return '${date.day} ${_months[date.month]} ${date.year}';
}

String _formatDateTime(DateTime? date) {
  if (date == null) return '';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${_formatDate(date)}, $hour:$minute $period';
}
