import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/profile/models/profile_model.dart';
import 'package:vigil_parents_app/features/profile/repo/profile_repo.dart';

enum ProfileViewState { idle, loading, loaded, error }

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel(this._repository);

  final ProfileRepository _repository;

  ProfileViewState _state = ProfileViewState.idle;
  ProfileViewState get state => _state;

  ProfileModel? _profile;
  ProfileModel? get profile => _profile;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _state == ProfileViewState.loading;
  bool get hasError => _state == ProfileViewState.error;

  Future<void> loadProfile({bool showLoader = true}) async {
    if (showLoader) {
      _state = ProfileViewState.loading;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      _profile = await _repository.getProfile();
      _state = ProfileViewState.loaded;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = ProfileViewState.error;
    }

    notifyListeners();
  }

  Future<void> refresh() => loadProfile(showLoader: false);
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final profileViewModelProvider = ChangeNotifierProvider<ProfileViewModel>((
  ref,
) {
  return ProfileViewModel(ref.read(profileRepositoryProvider));
});
