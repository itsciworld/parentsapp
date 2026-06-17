import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/location/models/location_model.dart';
import 'package:vigil_parents_app/features/location/presentation/view_model/location_viewmodel.dart'
    show locationRepositoryProvider;
import 'package:vigil_parents_app/features/location/repo/location_repo.dart';

/// Loads a child's recent location trail for a chosen time window. On-demand
/// only — the History screen calls [load] on open and on every change of child
/// or [hours]; there is no background polling.
class LocationHistoryViewModel extends ChangeNotifier {
  LocationHistoryViewModel(this._repository);

  final LocationRepository _repository;

  /// Selectable look-back windows (hours). Server caps the data at 48h.
  static const List<int> presetHours = [3, 6, 12, 24, 48];

  /// Currently selected window — defaults to the maximum (48h).
  int hours = 48;

  List<ChildLocation> locations = const [];
  bool loading = false;
  String? error;

  /// The point the user is currently inspecting (drives the map focus + card).
  ChildLocation? selected;

  String? _childId;
  String? get childId => _childId;

  /// The newest fix in the window, if any.
  ChildLocation? get latest => locations.isNotEmpty ? locations.first : null;

  Future<void> load(String childId, {int? hours}) async {
    if (hours != null) this.hours = hours;

    // Switching child clears the stale trail so we never flash old points.
    if (_childId != childId) {
      locations = const [];
      selected = null;
    }
    _childId = childId;

    loading = true;
    error = null;
    notifyListeners();

    try {
      final res = await _repository.getLocationHistory(
        childId: childId,
        hours: this.hours,
      );
      // Ignore a stale response if the selection changed while in flight.
      if (_childId != childId) return;
      locations = res.locations;
      // Default the inspected point to the most recent fix.
      selected = locations.isNotEmpty ? locations.first : null;
      error = null;
    } catch (e) {
      if (_childId != childId) return;
      locations = const [];
      selected = null;
      error = e.toString().replaceAll('Exception: ', '');
      if (kDebugMode) print('[LocationHistory] Load error: $error');
    } finally {
      if (_childId == childId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  /// Re-fetch the current child for a different window.
  Future<void> setHours(int value) async {
    if (value == hours) return;
    final id = _childId;
    if (id == null) {
      hours = value;
      notifyListeners();
      return;
    }
    await load(id, hours: value);
  }

  /// Focus a specific point (from a marker tap or list row).
  void select(ChildLocation location) {
    if (selected?.id == location.id) return;
    selected = location;
    notifyListeners();
  }
}

final locationHistoryViewModelProvider =
    ChangeNotifierProvider<LocationHistoryViewModel>((ref) {
      return LocationHistoryViewModel(ref.read(locationRepositoryProvider));
    });
