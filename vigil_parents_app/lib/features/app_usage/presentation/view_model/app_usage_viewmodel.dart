import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/app_usage/models/app_usage_model.dart';
import 'package:vigil_parents_app/features/app_usage/repo/app_usage_repo.dart';

/// Date range preset for app usage history filters.
enum AppUsageDateRange {
  today,
  yesterday,
  last3Days,
  lastWeek;

  String get label {
    switch (this) {
      case AppUsageDateRange.today:
        return 'Today';
      case AppUsageDateRange.yesterday:
        return 'Yesterday';
      case AppUsageDateRange.last3Days:
        return 'Last 3 Days';
      case AppUsageDateRange.lastWeek:
        return 'Last Week';
    }
  }

  /// The `period` query value understood by `/api/apps/history`. "today" is
  /// served by `/api/apps/get_apps` instead, so it has no history period.
  String? get historyPeriod {
    switch (this) {
      case AppUsageDateRange.today:
        return null;
      case AppUsageDateRange.yesterday:
        return 'yesterday';
      case AppUsageDateRange.last3Days:
        return '3days';
      case AppUsageDateRange.lastWeek:
        return '7days';
    }
  }
}

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

  /// Currently selected date range for history view.
  AppUsageDateRange _dateRange = AppUsageDateRange.today;
  AppUsageDateRange get dateRange => _dateRange;

  /// Whether we're viewing history (vs. current day stats).
  bool _isHistoryMode = false;
  bool get isHistoryMode => _isHistoryMode;

  /// Total tracked screen time across all apps, in minutes.
  int get totalMinutes => apps.fold(0, (sum, a) => sum + a.usageMinutes);

  /// Friendly total screen-time label, e.g. "1h 45m".
  String get totalLabel => AppUsage.formatMinutes(totalMinutes);

  /// Highest usage among apps (for chart scaling), at least 1.
  int get maxMinutes => apps.isEmpty
      ? 1
      : apps.map((a) => a.usageMinutes).reduce((a, b) => a > b ? a : b);

  /// The most-used apps, capped at [n].
  List<AppUsage> top([int n = 5]) =>
      apps.length <= n ? apps : apps.sublist(0, n);

  Future<void> load(String childId, {bool showLoader = true}) async {
    if (_childId != childId) {
      apps = const [];
      error = null;
      _isHistoryMode = false;
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

  /// Load app usage history for the selected date range.
  Future<void> loadHistory(
    String childId,
    AppUsageDateRange range, {
    bool showLoader = true,
  }) async {
    if (_childId != childId) {
      apps = const [];
      error = null;
    }
    _childId = childId;
    _dateRange = range;
    _isHistoryMode = true;

    if (showLoader) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      late final List<AppUsage> res;
      final period = range.historyPeriod;
      if (period == null) {
        // "Today" uses the same /api/apps/get_apps endpoint as the home card.
        if (kDebugMode) {
          print('📅 [AppUsage] ${range.label} → get_apps (today)');
        }
        res = await _repository.getApps(childId: childId);
      } else {
        if (kDebugMode) {
          print('📅 [AppUsage] ${range.label} → history?period=$period');
        }
        res = await _repository.getAppHistory(
          childId: childId,
          period: period,
        );
      }
      if (_childId != childId) return; // selection changed mid-flight
      apps = res;
      error = null;
      if (kDebugMode) {
        print('✅ [AppUsage] Loaded ${apps.length} apps for ${range.label}');
      }
    } catch (e) {
      if (_childId != childId) return;
      error = e.toString().replaceAll('Exception: ', '');
      if (kDebugMode) print('❌ [AppUsage] History load error: $error');
    } finally {
      if (_childId == childId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  /// Change the date range filter and reload history.
  Future<void> setDateRange(AppUsageDateRange range) async {
    final id = _childId;
    if (id == null) return;
    await loadHistory(id, range);
  }

  /// Silent reload of the current child — used for pull-to-refresh / polling.
  Future<void> refresh() async {
    final id = _childId;
    if (id == null) return;
    if (_isHistoryMode) {
      await loadHistory(id, _dateRange, showLoader: false);
    } else {
      await load(id, showLoader: false);
    }
  }

  /// Exit history mode and return to current stats.
  void exitHistoryMode() {
    _isHistoryMode = false;
    final id = _childId;
    if (id != null) {
      load(id);
    }
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
