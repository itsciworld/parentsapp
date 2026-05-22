import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/features/auth/presentation/view_model/auth_viewmodel.dart';
import 'package:vigil_parents_app/features/auth/repo/auth_repo.dart';

/// State for the 3-step forgot-password flow:
/// 1. request reset code  → [resetRequested]
/// 2. verify OTP          → [otpVerified]
/// 3. set new password    → [passwordReset]
///
/// Each step screen listens only for its own flag, so the shared provider
/// state can safely carry over while navigating between screens.
class ForgotPasswordState {
  final bool isLoading;
  final bool resetRequested;
  final bool otpVerified;
  final bool passwordReset;
  final AppToastData? toastData;

  ForgotPasswordState({
    this.isLoading = false,
    this.resetRequested = false,
    this.otpVerified = false,
    this.passwordReset = false,
    this.toastData,
  });

  ForgotPasswordState copyWith({
    bool? isLoading,
    bool? resetRequested,
    bool? otpVerified,
    bool? passwordReset,
    AppToastData? toastData,
    bool clearToast = false,
  }) {
    return ForgotPasswordState(
      isLoading: isLoading ?? this.isLoading,
      resetRequested: resetRequested ?? this.resetRequested,
      otpVerified: otpVerified ?? this.otpVerified,
      passwordReset: passwordReset ?? this.passwordReset,
      toastData: clearToast ? null : (toastData ?? this.toastData),
    );
  }
}

class ForgotPasswordViewModel extends StateNotifier<ForgotPasswordState> {
  final AuthRepository _authRepository;

  ForgotPasswordViewModel(this._authRepository)
    : super(ForgotPasswordState());

  // STEP 1 → request a reset code for the given email
  Future<void> requestPasswordReset(String email) async {
    state = state.copyWith(
      isLoading: true,
      resetRequested: false,
      clearToast: true,
    );

    try {
      final message = await _authRepository.requestPasswordReset(email);

      state = state.copyWith(
        isLoading: false,
        resetRequested: true,
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
          title: 'Request Failed',
          subtitle: e.toString().replaceAll('Exception: ', ''),
          type: ToastType.error,
        ),
      );
    }
  }

  // STEP 2 → verify the OTP entered by the user
  Future<void> verifyOtp(String email, String otp) async {
    state = state.copyWith(
      isLoading: true,
      otpVerified: false,
      clearToast: true,
    );

    try {
      final message = await _authRepository.verifyOtp(email, otp);

      state = state.copyWith(
        isLoading: false,
        otpVerified: true,
        toastData: AppToastData(
          title: 'Verified',
          subtitle: message,
          type: ToastType.success,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        toastData: AppToastData(
          title: 'Verification Failed',
          subtitle: e.toString().replaceAll('Exception: ', ''),
          type: ToastType.error,
        ),
      );
    }
  }

  // STEP 3 → set the new password using the verified OTP
  Future<void> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    state = state.copyWith(
      isLoading: true,
      passwordReset: false,
      clearToast: true,
    );

    try {
      final message = await _authRepository.resetPassword(
        email,
        otp,
        newPassword,
      );

      state = state.copyWith(
        isLoading: false,
        passwordReset: true,
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
          title: 'Reset Failed',
          subtitle: e.toString().replaceAll('Exception: ', ''),
          type: ToastType.error,
        ),
      );
    }
  }

  /// Reset the whole flow (call when leaving the flow entirely).
  void reset() => state = ForgotPasswordState();
}

final forgotPasswordViewModelProvider =
    StateNotifierProvider<ForgotPasswordViewModel, ForgotPasswordState>((ref) {
      final repo = ref.watch(authRepositoryProvider);
      return ForgotPasswordViewModel(repo);
    });
