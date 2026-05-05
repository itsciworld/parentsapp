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

class LoginState {
  final bool isLoading;
  final bool isSuccess;
  final AppToastData? toastData;

  LoginState({this.isLoading = false, this.isSuccess = false, this.toastData});

  LoginState copyWith({
    bool? isLoading,
    bool? isSuccess,
    AppToastData? toastData,
    bool clearToast = false,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      toastData: clearToast ? null : (toastData ?? this.toastData),
    );
  }
}

class LoginViewModel extends StateNotifier<LoginState> {
  final AuthRepository _authRepository;

  LoginViewModel(this._authRepository) : super(LoginState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearToast: true);
    try {
      final successMessage = await _authRepository.login(email, password);
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        toastData: AppToastData(
          title: 'Success',
          subtitle: successMessage,
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
}

final loginViewModelProvider =
    StateNotifierProvider<LoginViewModel, LoginState>((ref) {
      final authRepository = ref.watch(authRepositoryProvider);
      return LoginViewModel(authRepository);
    });
