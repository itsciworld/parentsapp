import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/child/models/child_permissions_model.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/repo/child_repo.dart';

/// Loads the permissions a single child has granted. Call [load] whenever the
/// selected child changes.
class ChildPermissionsViewModel extends ChangeNotifier {
  ChildPermissionsViewModel(this._repository);

  final ChildRepository _repository;

  ChildPermissions? permissions;
  bool loading = false;
  String? error;

  /// The child the current [permissions] belong to.
  String? _childId;

  Future<void> load(String childId) async {
    _childId = childId;
    loading = true;
    error = null;
    notifyListeners();

    try {
      final res = await _repository.fetchPermissions(childId);
      if (_childId != childId) return;
      permissions = res;
      error = null;
    } catch (e) {
      if (_childId != childId) return;
      permissions = null;
      error = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (_childId == childId) {
        loading = false;
        notifyListeners();
      }
    }
  }
}

final childPermissionsProvider =
    ChangeNotifierProvider<ChildPermissionsViewModel>((ref) {
      return ChildPermissionsViewModel(ref.read(childRepositoryProvider));
    });
