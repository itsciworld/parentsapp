import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/core/utils/refresh_guard.dart';
import 'package:vigil_parents_app/features/social_apps/models/social_screen_model.dart';
import 'package:vigil_parents_app/features/social_apps/repo/social_screen_repo.dart';

/// Loads captured social-app chat messages for the selected child and tracks
/// which app the user is currently viewing (defaults to the first available).
class SocialScreenViewModel extends ChangeNotifier with RefreshGuard {
  SocialScreenViewModel(this._repository);

  final SocialScreenRepository _repository;

  List<SocialAppMessages> apps = const [];
  int totalMessages = 0;
  bool loading = false;
  String? error;

  /// History window in days (server default is 2). Options: 1 / 2 / 3 / 5.
  int _days = 2;
  int get days => _days;

  /// The child the current [apps] belong to.
  String? _childId;
  String? get childId => _childId;

  /// Package of the app currently being viewed.
  String? _selectedPackage;
  String? get selectedPackage => _selectedPackage;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// The app currently selected for viewing, if any.
  SocialAppMessages? get selectedApp {
    if (_selectedPackage == null) return null;
    for (final a in apps) {
      if (a.package == _selectedPackage) return a;
    }
    return null;
  }

  /// The selected app's conversation threads, most-recently-active first.
  List<ScreenThread> get threads {
    final app = selectedApp;
    if (app == null) return const [];
    final list = [...app.threads];
    list.sort((a, b) => _cmpDesc(a.lastTime, b.lastTime));
    return list;
  }

  /// The selected app's messages (flat), newest-first. Kept for callers that
  /// still want an ungrouped feed.
  List<ScreenMessage> get messages {
    final app = selectedApp;
    if (app == null) return const [];
    final list = [...app.messages];
    list.sort((a, b) => _cmpDesc(a.timestamp, b.timestamp));
    return list;
  }

  static int _cmpDesc(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  Future<void> load(String childId, {bool showLoader = true}) async {
    if (_childId != childId) {
      apps = const [];
      totalMessages = 0;
      error = null;
      _selectedPackage = null;
    }
    _childId = childId;

    if (showLoader) {
      loading = true;
      error = null;
      _safeNotify();
    }

    try {
      final res = await _repository.getScreenMessages(
        childId: childId,
        days: _days,
      );
      if (_childId != childId) return; // selection changed mid-flight
      apps = res.apps;
      totalMessages = res.totalMessages;
      // Keep the current selection if still present, else default to the first.
      if (_selectedPackage == null ||
          !apps.any((a) => a.package == _selectedPackage)) {
        _selectedPackage = apps.isNotEmpty ? apps.first.package : null;
      }
      error = null;
    } catch (e) {
      if (_childId != childId) return;
      error = e.toString().replaceAll('Exception: ', '');
      if (kDebugMode) print('[SocialScreen] Load error: $error');
    } finally {
      if (_childId == childId) {
        loading = false;
        _safeNotify();
      }
    }
  }

  /// Silent reload of the current child — used for pull-to-refresh.
  Future<void> refresh() => guardedRefresh(() async {
    final id = _childId;
    if (id == null) return;
    await load(id, showLoader: false);
  });

  /// Switch the app being viewed.
  void select(String package) {
    if (_selectedPackage == package) return;
    _selectedPackage = package;
    _safeNotify();
  }

  /// Change the history window (in days) and reload the current child.
  Future<void> setDays(int days) async {
    if (_days == days) return;
    _days = days;
    _safeNotify();
    final id = _childId;
    if (id != null) await load(id);
  }
}

final socialScreenRepositoryProvider = Provider<SocialScreenRepository>((ref) {
  return SocialScreenRepository();
});

final socialScreenViewModelProvider =
    ChangeNotifierProvider<SocialScreenViewModel>((ref) {
      return SocialScreenViewModel(ref.read(socialScreenRepositoryProvider));
    });
