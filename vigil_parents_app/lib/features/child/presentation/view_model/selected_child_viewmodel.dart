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

  /// Fetches the children list and resolves the selected child from storage
  /// (falling back to the first child). Safe to call multiple times.
  Future<void> load({bool force = false}) async {
    if (loading) return;
    if (!force && children.isNotEmpty) return;

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
        await SecureDeviceService.saveSelectedChildId(selectedId!);
      } else {
        selectedId = null;
      }
      error = null;
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
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
    await SecureDeviceService.saveSelectedChildId(id);
    notifyListeners();
    return true;
  }
}

final selectedChildProvider =
    ChangeNotifierProvider<SelectedChildViewModel>((ref) {
      return SelectedChildViewModel(ref.read(childRepositoryProvider));
    });
