import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/core/services/biometric/biometric_auth_service.dart';
import 'package:vigil_parents_app/features/auth/repo/auth_repo.dart';

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AppToastData {
  final String title;
  final String subtitle;
  final ToastType type;

  AppToastData({
    required this.title,
    required this.subtitle,
    required this.type,
  });
}

class AuthState {
  final bool isLoading;

  /// Kept separate from [isLoading] so the spinner appears on whichever control
  /// was actually tapped — the Login button, or the biometric icon — instead of
  /// both flows lighting up the same one.
  final bool isBiometricLoading;

  final bool isSuccess;
  final AppToastData? toastData;

  AuthState({
    this.isLoading = false,
    this.isBiometricLoading = false,
    this.isSuccess = false,
    this.toastData,
  });

  /// True while either sign-in path is running. Each control uses this to
  /// disable itself, and its own flag to decide whether to show the spinner.
  bool get isBusy => isLoading || isBiometricLoading;

  AuthState copyWith({
    bool? isLoading,
    bool? isBiometricLoading,
    bool? isSuccess,
    AppToastData? toastData,
    bool clearToast = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isBiometricLoading: isBiometricLoading ?? this.isBiometricLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      toastData: clearToast ? null : (toastData ?? this.toastData),
    );
  }
}

class AuthViewModel extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthViewModel(this._authRepository) : super(AuthState());

  // LOGIN
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, isSuccess: false, clearToast: true);

    try {
      final message = await _authRepository.login(email, password);

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        toastData: AppToastData(
          title: 'Success',
          subtitle: message,
          type: ToastType.success,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        toastData: AppToastData(
          title: 'Login Failed',
          subtitle: e.toString().replaceAll('Exception: ', ''),
          type: ToastType.error,
        ),
      );
    }
  }

  /// LOGIN VIA BIOMETRICS — scan first, then replay the credentials stored at
  /// enrolment against the normal login endpoint. There is no separate
  /// biometric session: a successful scan produces an ordinary token, so
  /// everything downstream is unchanged.
  Future<void> loginWithBiometrics() async {
    state = state.copyWith(
      isBiometricLoading: true,
      isSuccess: false,
      clearToast: true,
    );

    final scan = await BiometricAuthService.prompt(
      'Confirm your identity to log in to Vigil Parents',
    );

    if (!scan.isSuccess) {
      // Backing out of the system sheet is not an error — say nothing.
      state = scan.isCancelled
          ? state.copyWith(isBiometricLoading: false, clearToast: true)
          : state.copyWith(
              isBiometricLoading: false,
              toastData: AppToastData(
                title: 'Biometric Login Failed',
                subtitle:
                    scan.message ?? 'Could not verify you. Please try again.',
                type: ToastType.error,
              ),
            );
      return;
    }

    final credentials = await BiometricAuthService.readCredentials();
    if (credentials == null) {
      // The scan passed but the vault is gone (Keychain wiped, app data
      // cleared). Turn the flag off so the shortcut stops being offered.
      await BiometricAuthService.disable();
      state = state.copyWith(
        isBiometricLoading: false,
        toastData: AppToastData(
          title: 'Biometric Login Unavailable',
          subtitle:
              'Please log in with your password and turn biometric login on '
              'again from your profile.',
          type: ToastType.error,
        ),
      );
      return;
    }

    try {
      final message = await _authRepository.login(
        credentials.email,
        credentials.password,
      );

      state = state.copyWith(
        isBiometricLoading: false,
        isSuccess: true,
        toastData: AppToastData(
          title: 'Success',
          subtitle: message,
          type: ToastType.success,
        ),
      );
    } on InvalidCredentialsException {
      // The stored password no longer opens the account — a reset elsewhere is
      // the usual cause. Drop the enrolment rather than let the scan keep
      // failing for a reason the parent can't see.
      await BiometricAuthService.disable();
      state = state.copyWith(
        isBiometricLoading: false,
        toastData: AppToastData(
          title: 'Biometric Login Failed',
          subtitle:
              'Your sign-in details have changed. Log in with your password, '
              'then turn biometric login on again.',
          type: ToastType.error,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        isBiometricLoading: false,
        toastData: AppToastData(
          title: 'Login Failed',
          subtitle: e.toString().replaceAll('Exception: ', ''),
          type: ToastType.error,
        ),
      );
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, isSuccess: false, clearToast: true);

    try {
      final message = await _authRepository.register(name, email, password);

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        toastData: AppToastData(
          title: 'Success',
          subtitle: message,
          type: ToastType.success,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        toastData: AppToastData(
          title: 'Registration Failed',
          subtitle: e.toString().replaceAll('Exception: ', ''),
          type: ToastType.error,
        ),
      );
    }
  }
}

final authViewModelProvider = StateNotifierProvider<AuthViewModel, AuthState>((
  ref,
) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthViewModel(repo);
});
