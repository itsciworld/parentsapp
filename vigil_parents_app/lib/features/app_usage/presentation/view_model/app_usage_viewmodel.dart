import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/app_usage/models/app_usage_model.dart';
import 'package:vigil_parents_app/features/app_usage/repo/app_usage_repo.dart';

/// Loads app-usage stats for the selected child. Shared between the Home
/// "Activity Overview" card and the full-screen detail view, so switching child
/// in one reflects in the other. Apps are kept sorted by usage (most first).
class AppUsageViewModel extends ChangeNotifier {
  AppUsageViewModel(this._repository);

  final AppUsageRepository _repository;

  List<AppUsage> apps = const [];
  bool loading = false;
  String? error;

  /// The child the current [apps] belong to.
  String? _childId;
  String? get childId => _childId;

  /// Total tracked screen time across all apps, in minutes.
  int get totalMinutes => apps.fold(0, (sum, a) => sum + a.usageMinutes);

  /// Friendly total screen-time label, e.g. "1h 45m".
  String get totalLabel => AppUsage.formatMinutes(totalMinutes);

  /// Highest usage among apps (for chart scaling), at least 1.
  int get maxMinutes =>
      apps.isEmpty ? 1 : apps.map((a) => a.usageMinutes).reduce((a, b) => a > b ? a : b);

  /// The most-used apps, capped at [n].
  List<AppUsage> top([int n = 5]) =>
      apps.length <= n ? apps : apps.sublist(0, n);

  Future<void> load(String childId, {bool showLoader = true}) async {
    if (_childId != childId) {
      apps = const [];
      error = null;
    }
    _childId = childId;

    if (showLoader) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      final res = await _repository.getApps(childId: childId);
      if (_childId != childId) return; // selection changed mid-flight
      apps = res;
      error = null;
    } catch (e) {
      if (_childId != childId) return;
      error = e.toString().replaceAll('Exception: ', '');
      if (kDebugMode) print('[AppUsage] Load error: $error');
    } finally {
      if (_childId == childId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  /// Silent reload of the current child — used for pull-to-refresh / polling.
  Future<void> refresh() async {
    final id = _childId;
    if (id == null) return;
    await load(id, showLoader: false);
  }
}

final appUsageRepositoryProvider = Provider<AppUsageRepository>((ref) {
  return AppUsageRepository();
});

final appUsageViewModelProvider = ChangeNotifierProvider<AppUsageViewModel>((
  ref,
) {
  return AppUsageViewModel(ref.read(appUsageRepositoryProvider));
});
