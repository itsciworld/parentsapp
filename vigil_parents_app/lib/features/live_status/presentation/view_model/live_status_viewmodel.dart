import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/live_status/models/live_status_model.dart';
import 'package:vigil_parents_app/features/live_status/repo/live_status_repo.dart';

/// Loads and live-polls the battery + connectivity status for a single child.
///
/// "Last sync" is the moment this view model last fetched the endpoint
/// successfully — every successful call to [load]/[refresh] updates it.
class LiveStatusViewModel extends ChangeNotifier {
  LiveStatusViewModel(this._repository);

  final LiveStatusRepository _repository;

  /// How often the screen re-polls the endpoint while it is in the foreground.
  static const Duration _pollInterval = Duration(seconds: 30);

  LiveStatusResponse? status;
  bool loading = false;
  String? error;

  /// Local time of the last successful fetch — drives the "Last sync" stat.
  DateTime? lastSyncAt;

  /// The child the current [status] belongs to.
  String? _childId;
  String? get childId => _childId;

  Timer? _timer;
  bool _disposed = false;

  int? get batteryLevel => status?.battery.level;
  bool get isOnline => status?.isOnline ?? false;

  /// Fetches the live status for [childId]. Shows the loader on the first load
  /// for a child; subsequent refreshes update silently.
  Future<void> load(String childId, {bool showLoader = true}) async {
    final isNewChild = _childId != childId;
    _childId = childId;

    if (showLoader && isNewChild) {
      loading = true;
      error = null;
      _safeNotify();
    }

    try {
      final res = await _repository.fetchLiveStatus(childId);
      // Ignore a stale response if the selection changed while in flight.
      if (_childId != childId) return;
      status = res;
      lastSyncAt = DateTime.now();
      error = null;
    } catch (e) {
      if (_childId != childId) return;
      // Keep the previous data on a silent refresh so a transient failure
      // doesn't blank the card.
      error = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (_childId == childId) {
        loading = false;
        _safeNotify();
      }
    }
  }

  /// Re-fetches without toggling the loader.
  Future<void> refresh() {
    final id = _childId;
    if (id == null) return Future.value();
    return load(id, showLoader: false);
  }

  /// Begins foreground polling for [childId]: an immediate fetch followed by a
  /// periodic refresh. Safe to call when the selected child changes — it resets
  /// the timer to the new child.
  void startPolling(String childId) {
    _timer?.cancel();
    load(childId);
    _timer = Timer.periodic(_pollInterval, (_) => refresh());
  }

  /// Stops foreground polling (e.g. when the screen leaves the foreground).
  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

final liveStatusRepositoryProvider = Provider<LiveStatusRepository>((ref) {
  return LiveStatusRepository();
});

final liveStatusViewModelProvider =
    ChangeNotifierProvider<LiveStatusViewModel>((ref) {
      return LiveStatusViewModel(ref.read(liveStatusRepositoryProvider));
    });
