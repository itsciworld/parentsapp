import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
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
  final bool isSuccess;
  final AppToastData? toastData;

  AuthState({this.isLoading = false, this.isSuccess = false, this.toastData});

  AuthState copyWith({
    bool? isLoading,
    bool? isSuccess,
    AppToastData? toastData,
    bool clearToast = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
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
    state = state.copyWith(isLoading: true, clearToast: true);

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

  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, clearToast: true);

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
