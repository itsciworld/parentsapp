import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/features/child/models/child_model.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/repo/child_repo.dart';

/// Owns the "currently selected child" across the app (Home + SMS).
///
/// The selection is persisted via [SecureDeviceService] so the background SMS
/// service and every screen stay in sync.
class SelectedChildViewModel extends ChangeNotifier {
  SelectedChildViewModel(this._repository);

  final ChildRepository _repository;

  List<ChildModel> children = const [];
  String? selectedId;
  bool loading = false;
  String? error;

  /// True once the first fetch has completed (success or failure). Used by the
  /// UI to distinguish "still loading" from "loaded but no children".
  bool initialized = false;

  /// The full model for the currently selected child, if available.
  ChildModel? get selected {
    if (selectedId == null) return null;
    for (final c in children) {
      if (c.id == selectedId) return c;
    }
    return null;
  }

  /// The load currently in flight, so concurrent callers share it instead of
  /// each starting their own fetch.
  Future<void>? _inFlight;

  /// Fetches the children list and resolves the selected child from storage
  /// (falling back to the first child). Safe to call multiple times.
  ///
  /// Awaiting this always means "the selection is resolved". Callers rely on
  /// that — nearly every screen does `await load(); final id = selectedId;`.
  /// Returning early while a load was still running handed those callers a
  /// null id and silently skipped their fetch, which is what left the home
  /// screen's location card empty until the detail screen was opened.
  Future<void> load({bool force = false}) {
    final pending = _inFlight;
    if (pending != null) return pending;
    if (!force && children.isNotEmpty && selectedId != null) {
      return Future.value();
    }

    final run = _load().whenComplete(() => _inFlight = null);
    _inFlight = run;
    return run;
  }

  Future<void> _load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      children = await _repository.fetchChildren();

      final stored = await SecureDeviceService.getSelectedChildId();
      if (stored != null && children.any((c) => c.id == stored)) {
        selectedId = stored;
      } else if (children.isNotEmpty) {
        selectedId = children.first.id;
      } else {
        selectedId = null;
      }
      // Persist the resolved selection (id + device key) so API calls and the
      // background service pick up the right child. This ensures the device key
      // is always fresh from the API, even if the child was previously selected.
      await _persistSelection();

      if (kDebugMode) {
        print('[SelectedChild] Loaded ${children.length} children');
        if (selected != null) {
          print(
            '[SelectedChild] Selected: ${selected!.name} (${selected!.id})',
          );
          print('[SelectedChild] Device Key: ${selected!.deviceKey}');
        }
      }

      error = null;
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
      if (kDebugMode) {
        print('[SelectedChild] Load error: $error');
      }
    } finally {
      loading = false;
      initialized = true;
      notifyListeners();
    }
  }

  /// Switches the selected child and persists it. Returns true if it changed.
  Future<bool> select(String id) async {
    if (id == selectedId) return false;
    selectedId = id;
    await _persistSelection();
    notifyListeners();
    return true;
  }

  /// Persists the current selection — both the child id and its per-device key
  /// — so child-scoped API calls send the right `x-device-key`.
  Future<void> _persistSelection() async {
    final child = selected;
    if (child == null) return;
    await SecureDeviceService.saveSelectedChildId(child.id);
    await SecureDeviceService.saveSelectedChildDeviceKey(child.deviceKey);
  }
}

final selectedChildProvider = ChangeNotifierProvider<SelectedChildViewModel>((
  ref,
) {
  return SelectedChildViewModel(ref.read(childRepositoryProvider));
});
