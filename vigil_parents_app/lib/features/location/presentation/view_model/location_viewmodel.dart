import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/location/models/location_model.dart';
import 'package:vigil_parents_app/features/location/repo/location_repo.dart';

/// Loads the location history for the selected child and exposes the most
/// recent fix. Shared between the Home map card and the full-screen detail
/// view, so switching child in one reflects in the other. Call [load] whenever
/// the selected child changes.
class LocationViewModel extends ChangeNotifier {
  LocationViewModel(this._repository);

  final LocationRepository _repository;

  List<ChildLocation> locations = const [];
  bool loading = false;
  String? error;

  /// The child the current [locations] belong to.
  String? _childId;
  String? get childId => _childId;

  /// The most recent fix (locations are sorted newest-first by the repo).
  ChildLocation? get latest => locations.isNotEmpty ? locations.first : null;

  Future<void> load(String childId, {bool showLoader = true}) async {
    // Switching child clears stale points so we never flash the wrong marker.
    if (_childId != childId) {
      locations = const [];
      error = null;
    }
    _childId = childId;

    if (showLoader) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      final res = await _repository.getLocations(childId: childId);
      // Ignore a stale response if the selection changed while in flight.
      if (_childId != childId) return;
      locations = res;
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
  Future<void> refresh() async {
    final id = _childId;
    if (id == null) return;
    await load(id, showLoader: false);
  }
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

final locationViewModelProvider = ChangeNotifierProvider<LocationViewModel>((
  ref,
) {
  return LocationViewModel(ref.read(locationRepositoryProvider));
});
