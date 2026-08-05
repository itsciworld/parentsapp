import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/features/auth/presentation/view_model/auth_viewmodel.dart';
import 'package:vigil_parents_app/features/auth/repo/auth_repo.dart';

/// State for the 2-step registration flow:
/// 1. email a verification code → [otpSent]
/// 2. create the account with it → [isRegistered]
///
/// Each screen listens only for its own flag, so the shared provider state can
/// safely carry over while navigating between them. [otpSent] deliberately
/// stays true across a resend — flipping it back would make the signup screen,
/// still mounted underneath, push a second OTP screen.
class RegisterState {
  final bool isLoading;
  final bool otpSent;
  final bool isRegistered;
  final AppToastData? toastData;

  RegisterState({
    this.isLoading = false,
    this.otpSent = false,
    this.isRegistered = false,
    this.toastData,
  });

  RegisterState copyWith({
    bool? isLoading,
    bool? otpSent,
    bool? isRegistered,
    AppToastData? toastData,
    bool clearToast = false,
  }) {
    return RegisterState(
      isLoading: isLoading ?? this.isLoading,
      otpSent: otpSent ?? this.otpSent,
      isRegistered: isRegistered ?? this.isRegistered,
      toastData: clearToast ? null : (toastData ?? this.toastData),
    );
  }
}

class RegisterViewModel extends StateNotifier<RegisterState> {
  final AuthRepository _authRepository;

  RegisterViewModel(this._authRepository) : super(RegisterState());

  // STEP 1 → email a one-time code. Also used by the OTP screen's "Resend".
  Future<void> sendRegisterOtp(String name, String email) async {
    state = state.copyWith(isLoading: true, clearToast: true);

    try {
      final message = await _authRepository.sendRegisterOtp(name, email);

      state = state.copyWith(
        isLoading: false,
        otpSent: true,
        toastData: AppToastData(
          title: 'Code Sent',
          subtitle: message,
          type: ToastType.success,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        toastData: AppToastData(
          title: 'Could Not Send Code',
          subtitle: e.toString().replaceAll('Exception: ', ''),
          type: ToastType.error,
        ),
      );
    }
  }

  // STEP 2 → create the account. A success here means the repository has
  // already stored the session, so the caller can go straight to the dashboard.
  Future<void> registerWithOtp({
    required String name,
    required String email,
    required String password,
    required String otp,
  }) async {
    state = state.copyWith(
      isLoading: true,
      isRegistered: false,
      clearToast: true,
    );

    try {
      final message = await _authRepository.registerWithOtp(
        name: name,
        email: email,
        password: password,
        otp: otp,
      );

      state = state.copyWith(
        isLoading: false,
        isRegistered: true,
        toastData: AppToastData(
          title: 'Welcome',
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

  /// Clears the flow. The signup screen calls this before every fresh attempt
  /// so that re-submitting (e.g. after correcting the email) navigates again.
  void reset() => state = RegisterState();
}

final registerViewModelProvider =
    StateNotifierProvider<RegisterViewModel, RegisterState>((ref) {
      final repo = ref.watch(authRepositoryProvider);
      return RegisterViewModel(repo);
    });
