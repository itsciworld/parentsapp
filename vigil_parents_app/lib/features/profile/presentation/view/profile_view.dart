import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/core/routing/routes.dart';
import 'package:vigil_parents_app/core/services/biometric/biometric_auth_service.dart';
import 'package:vigil_parents_app/features/auth/repo/auth_repo.dart';
import 'package:vigil_parents_app/features/child/models/child_permissions_model.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/child_permissions_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/main_shell/shell_tabs.dart';
import 'package:vigil_parents_app/features/profile/models/profile_model.dart';
import 'package:vigil_parents_app/features/profile/presentation/view_model/profile_viewmodel.dart';
import 'package:vigil_parents_app/features/subscription/models/subscription_model.dart';
import 'package:vigil_parents_app/features/subscription/presentation/view_model/subscription_viewmodel.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  bool _isLoggingOut = false;

  /// Whether the phone itself can run a scan (hardware present *and* something
  /// enrolled in the OS). The whole security card is hidden when it can't —
  /// offering a switch that could never work would only confuse.
  bool _biometricAvailable = false;

  /// Whether biometric login is currently switched on for this account.
  bool _biometricEnabled = false;

  BiometricKind _biometricKind = BiometricKind.generic;

  /// Guards the toggle while a scan / verification is in flight, so a double
  /// tap can't start two enrolments.
  bool _biometricBusy = false;

  @override
  void initState() {
    super.initState();

    _loadBiometricState();

    Future.microtask(() async {
      ref.read(profileViewModelProvider).loadProfile();
      ref.read(subscriptionViewModelProvider).load(showLoader: false);
      // Load the selected child, then permissions for the active child.
      await ref.read(selectedChildProvider).load();
      final childId = ref.read(selectedChildProvider).selectedId;
      if (childId != null) {
        ref.read(childPermissionsProvider).load(childId);
      }
    });
  }

  /// Profile stays alive in the shell's [IndexedStack], so `initState` only
  /// runs on the first visit. Re-fetch the profile and the child's permissions
  /// every time the tab is opened, so what is on screen is never stale.
  Future<void> _refreshOnVisible() async {
    ref.read(profileViewModelProvider).loadProfile();
    await ref.read(selectedChildProvider).load();
    if (!mounted) return;
    final childId = ref.read(selectedChildProvider).selectedId;
    if (childId != null) {
      await ref.read(childPermissionsProvider).load(childId);
    }
  }

  /// Pull-to-refresh: reloads the profile and the child's permissions.
  Future<void> _refreshAll() async {
    await ref.read(profileViewModelProvider).refresh();
    await ref.read(subscriptionViewModelProvider).refresh();
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

    // Re-entering the Profile tab reloads the screen — see [_refreshOnVisible].
    ref.listen<int>(visibleTabProvider, (previous, next) {
      if (next == ShellTabs.profile && previous != next) _refreshOnVisible();
    });

    final vm = ref.watch(profileViewModelProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final permsVm = ref.watch(childPermissionsProvider);

    // Safety net: if permissions haven't loaded for the selected child yet,
    // kick it off — but *after* this frame. Modifying a provider during build
    // (which load() does via notifyListeners) throws in Riverpod.
    if (selectedChild.selectedId != null &&
        permsVm.permissions == null &&
        !permsVm.loading) {
      // Deferred out of build — load() calls notifyListeners synchronously,
      // and modifying a provider during build throws in Riverpod.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final id = ref.read(selectedChildProvider).selectedId;
        final perms = ref.read(childPermissionsProvider);
        if (id != null && perms.permissions == null && !perms.loading) {
          perms.load(id);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // VIGIL logo header — same pattern as every other tab (Home,
            // AI Insights, SMS …): logo first, then the screen's details.
            const AppHeader(showBack: false),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refreshAll,
                child: _buildBody(vm),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Biometric login ────────────────────────────────────────────────────────

  Future<void> _loadBiometricState() async {
    final available = await BiometricAuthService.isAvailable();
    final enabled = await BiometricAuthService.isEnabled();
    final kind = available
        ? await BiometricAuthService.kind()
        : BiometricKind.generic;

    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
      _biometricKind = kind;
    });
  }

  Future<void> _onBiometricToggled(bool value, String email) async {
    if (_biometricBusy) return;
    setState(() => _biometricBusy = true);
    try {
      if (value) {
        await _enableBiometricLogin(email);
      } else {
        await _disableBiometricLogin();
      }
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  Future<void> _disableBiometricLogin() async {
    await BiometricAuthService.disable();
    if (!mounted) return;
    setState(() => _biometricEnabled = false);
    showAppToast(
      context: context,
      title: 'Biometric Login Off',
      subtitle: 'You will need your password the next time you log in.',
      type: ToastType.info,
    );
  }

  Future<void> _enableBiometricLogin(String email) async {
    // Scan first: enrolling is a security change, so it must be the account
    // holder's own finger/face doing it, not whoever happens to be holding an
    // already-unlocked phone.
    final scan = await BiometricAuthService.prompt(
      'Confirm your identity to turn on biometric login',
    );
    if (!mounted) return;

    if (!scan.isSuccess) {
      if (!scan.isCancelled) {
        showAppToast(
          context: context,
          title: 'Could Not Turn On',
          subtitle: scan.message ?? 'Biometric authentication failed.',
          type: ToastType.error,
        );
      }
      return;
    }

    // The password from this session's own login, if there was one. That is
    // the normal path — the parent enrols without retyping anything.
    var password = BiometricAuthService.cachedPasswordFor(email);
    var needsVerification = false;

    if (password == null) {
      // Cold start: the app is running on a restored session and never saw the
      // password. It has to be confirmed once, because the vault is what a
      // future biometric login replays.
      password = await _askForPassword();
      if (!mounted || password == null || password.isEmpty) return;
      needsVerification = true;
    }

    if (needsVerification) {
      try {
        // Verifying through the real login endpoint is the only way to know the
        // password works; it also refreshes this session's tokens, which is
        // harmless.
        await AuthRepository().login(email, password);
      } on InvalidCredentialsException {
        if (!mounted) return;
        showAppToast(
          context: context,
          title: 'Incorrect Password',
          subtitle: 'Please check your password and try again.',
          type: ToastType.error,
        );
        return;
      } catch (e) {
        if (!mounted) return;
        showAppToast(
          context: context,
          title: 'Could Not Turn On',
          subtitle: e.toString().replaceAll('Exception: ', ''),
          type: ToastType.error,
        );
        return;
      }
    }

    await BiometricAuthService.enable(email: email, password: password);
    if (!mounted) return;

    setState(() => _biometricEnabled = true);
    showAppToast(
      context: context,
      title: 'Biometric Login On',
      subtitle:
          'Next time, tap the ${_biometricKind.label} icon on the login '
          'screen to sign in.',
      type: ToastType.success,
    );
  }

  /// One-off password confirmation, shown only when this app run did not
  /// perform the login itself. Returns null if the parent backs out.
  Future<String?> _askForPassword() {
    final controller = TextEditingController();
    var obscure = true;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Confirm your password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your password once so biometric login can sign you in '
                'later.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                obscureText: obscure,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => Navigator.of(ctx).pop(v),
                decoration: InputDecoration(
                  hintText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
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
    final subVm = ref.watch(subscriptionViewModelProvider);
    final hasChild = selectedChild.selected != null;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _ProfileHeader(profile: profile),
        const SizedBox(height: 20),
        if (hasChild) ...[
          _CurrentPlanCard(
            sub: subVm.mySubscription,
            loading: subVm.isLoading && subVm.plans.isEmpty,
            onManage: () =>
                Navigator.of(context).pushNamed(AppRoutesName.plansView),
          ),
          const SizedBox(height: 16),
        ],
        _InfoSection(
          title: 'Location',
          icon: Icons.location_on_outlined,
          rows: [
            _InfoRow(label: 'Country', value: profile.country),
            _InfoRow(label: 'City', value: profile.city),
            _InfoRow(label: 'Address', value: profile.address),
          ],
        ),
        const SizedBox(height: 16),
        _InfoSection(
          title: 'Account',
          icon: Icons.shield_outlined,
          rows: [
            _InfoRow(label: 'Status', value: _capitalize(profile.status)),
            // "Registered Via" is intentionally not shown here. It carries no
            // meaning for the parent; it exists for our own accountability and
            // belongs in the super-admin view. The field is still parsed off
            // /api/auth/me — see ProfileModel.registeredVia — so nothing is
            // lost by hiding it.
            _InfoRow(
              label: 'Member Since',
              value: _formatDate(profile.createdAt),
            ),
            _InfoRow(
              label: 'Last Login',
              value: _formatDateTime(profile.lastLogin),
            ),
          ],
        ),
        // Hidden on a device that can't scan — offering a switch that could
        // never work only confuses. The one exception is an enrolment that is
        // already on: the phone's fingerprints may have been removed since,
        // and the card is the only way to clear the stored credentials.
        if ((_biometricAvailable || _biometricEnabled) &&
            profile.email.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _BiometricSection(
            kind: _biometricKind,
            enabled: _biometricEnabled,
            available: _biometricAvailable,
            busy: _biometricBusy,
            onChanged: (value) =>
                _onBiometricToggled(value, profile.email.trim()),
          ),
        ],
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
        if (hasChild && !subVm.isOnTopPlan) ...[
          _UpgradeButton(
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutesName.plansView),
          ),
          const SizedBox(height: 12),
        ],
        _LogoutButton(isLoading: _isLoggingOut, onTap: _confirmAndLogout),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            // Mirrors pubspec.yaml `version: 1.0.0+1`.
            'Version 1.0.0 (Build 1)',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
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

// ── Header (centered, sits on the scaffold background) ───────────────────────────
class _ProfileHeader extends StatelessWidget {
  final ProfileModel profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Avatar with a soft ring + verified badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primary,
                child: Text(
                  _initialsFor(profile.name),
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                  ),
                ),
              ),
            ),
            if (profile.isVerified)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: AppColors.textOnDark,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          profile.name.isEmpty ? 'Unnamed' : profile.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          profile.email,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.5,
          ),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
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
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty ? '—' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            display,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Biometric login card ─────────────────────────────────────────────────────────
class _BiometricSection extends StatelessWidget {
  const _BiometricSection({
    required this.kind,
    required this.enabled,
    required this.available,
    required this.busy,
    required this.onChanged,
  });

  final BiometricKind kind;
  final bool enabled;

  /// Whether the device can currently run a scan. False with [enabled] true
  /// means the parent removed their fingerprints/face after enrolling.
  final bool available;

  final bool busy;
  final ValueChanged<bool> onChanged;

  String get _subtitle {
    if (enabled && !available) {
      return 'No fingerprint or face is set up on this device any more. Add '
          'one in your device settings, or turn this off.';
    }
    return enabled
        ? 'Log back in with a scan instead of your password.'
        : 'Skip typing your password the next time you log in.';
  }

  IconData get _icon {
    switch (kind) {
      case BiometricKind.face:
        return Icons.face_retouching_natural_rounded;
      case BiometricKind.iris:
        return Icons.remove_red_eye_outlined;
      case BiometricKind.fingerprint:
      case BiometricKind.generic:
        return Icons.fingerprint_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
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
                Icons.lock_outline_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              const Text(
                'Security',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${kind.label} Login',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: enabled && !available
                            ? AppColors.warning
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // The switch is swapped for a spinner while a scan is running, so
              // its position can't be tapped again mid-enrolment.
              busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Switch.adaptive(
                      value: enabled,
                      activeThumbColor: AppColors.primary,
                      onChanged: onChanged,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Child permissions card (grid of toggle tiles) ────────────────────────────────
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
        borderRadius: BorderRadius.circular(18),
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
                Icons.vpn_key_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              const Text(
                'App Permissions',
                style: TextStyle(
                  fontSize: 16,
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
          const SizedBox(height: 14),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final tileWidth = (constraints.maxWidth - spacing * 2) / 3;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: tileWidth,
                  child: _PermissionTile(item: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final PermissionItem item;
  const _PermissionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final granted = item.granted;
    final accent = granted ? AppColors.primary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 18, color: accent),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: Center(
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _StatusBadge(on: granted),
        ],
      ),
    );
  }
}

/// A read-only status badge showing whether a permission is granted.
///
/// Rendered as a static pill (icon + label) so it clearly reads as a
/// state indicator rather than an interactive toggle.
class _StatusBadge extends StatelessWidget {
  final bool on;
  const _StatusBadge({required this.on});

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.primary : AppColors.textSecondary;
    final bg = on ? AppColors.primaryLight : const Color(0xFFEDEFF3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            on ? Icons.check_circle : Icons.remove_circle_outline,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            on ? 'Allowed' : 'Blocked',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Current plan / subscription card ─────────────────────────────────────────────
// Kept for when the paid version is enabled again; not currently used.
// ignore: unused_element
class _CurrentPlanCard extends StatelessWidget {
  final MySubscription sub;
  final bool loading;
  final VoidCallback onManage;

  const _CurrentPlanCard({
    required this.sub,
    required this.loading,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final hasSub = sub.hasSubscription;
    final planLabel = hasSub && sub.planName.trim().isNotEmpty
        ? sub.planName.trim()
        : 'Free plan';

    // Status pill text/colour.
    final String statusText;
    final Color statusColor;
    if (loading && !hasSub) {
      statusText = '—';
      statusColor = AppColors.textSecondary;
    } else if (sub.inTrial || sub.status.toLowerCase() == 'trial') {
      statusText = 'Trial';
      statusColor = AppColors.warning;
    } else if (hasSub) {
      statusText = 'Active';
      statusColor = AppColors.primary;
    } else {
      statusText = 'Free';
      statusColor = AppColors.textSecondary;
    }

    final days = sub.inTrial ? sub.trialDaysRemaining : sub.daysRemaining;
    final subtitle = !hasSub
        ? 'No paid subscription yet'
        : sub.inTrial
        ? '$days days left in trial'
        : days > 0
        ? '$days days remaining'
        : 'Active subscription';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
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
                Icons.workspace_premium_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              const Text(
                'Current Plan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onManage,
                child: const Text(
                  'View plans',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Upgrade plan button (primary gradient, leads to the plans screen) ────────────
// Kept for when the paid version is enabled again; not currently used.
// ignore: unused_element
class _UpgradeButton extends StatelessWidget {
  final VoidCallback onTap;

  const _UpgradeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Gradient premium badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.blueIcon],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade Plan',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Unlock all monitoring features',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Accent chip with arrow
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Upgrade',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: AppColors.primaryDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logout button (soft red, matching the reference) ─────────────────────────────
class _LogoutButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _LogoutButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isLoading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.alert.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.alert,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 20,
                        color: AppColors.alert,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Log out',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.alert,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
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
