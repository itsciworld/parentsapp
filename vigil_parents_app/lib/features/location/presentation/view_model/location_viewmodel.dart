import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/core/utils/refresh_guard.dart';
import 'package:vigil_parents_app/features/location/models/location_model.dart';
import 'package:vigil_parents_app/features/location/repo/location_repo.dart';

/// Loads the location history for the selected child and exposes the most
/// recent fix. Shared between the Home map card and the full-screen detail
/// view, so switching child in one reflects in the other. Call [load] whenever
/// the selected child changes.
class LocationViewModel extends ChangeNotifier with RefreshGuard {
  LocationViewModel(this._repository);

  final LocationRepository _repository;

  /// The child's most recent fix, refreshed in place from
  /// `/api/locations/latest/{childId}`.
  ChildLocation? latest;
  bool loading = false;
  String? error;

  /// The child the current [latest] fix belongs to.
  String? _childId;
  String? get childId => _childId;

  Future<void> load(String childId, {bool showLoader = true}) async {
    // Switching child clears the stale fix so we never flash the wrong marker.
    if (_childId != childId) {
      latest = null;
      error = null;
    }
    _childId = childId;

    if (showLoader) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      final res = await _repository.getLatestLocation(childId: childId);
      // Ignore a stale response if the selection changed while in flight.
      if (_childId != childId) return;
      latest = res;
      error = null;
    } catch (e) {
      if (_childId != childId) return;
      error = e.toString().replaceAll('Exception: ', '');
      if (kDebugMode) print('[Location] Load error: $error');
    } finally {
      if (_childId == childId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  /// Silent reload of the current child — used for pull-to-refresh / polling.
  ///
  /// [fallbackChildId] is used when no child has been loaded yet. Without it a
  /// tick that finds this view model empty returns immediately and keeps doing
  /// so forever, so a first load that never ran was never recovered from.
  Future<void> refresh({String? fallbackChildId}) => guardedRefresh(() async {
    final id = _childId ?? fallbackChildId;
    if (id == null) return;
    await load(id, showLoader: false);
  });
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

final locationViewModelProvider = ChangeNotifierProvider<LocationViewModel>((
  ref,
) {
  return LocationViewModel(ref.read(locationRepositoryProvider));
});
