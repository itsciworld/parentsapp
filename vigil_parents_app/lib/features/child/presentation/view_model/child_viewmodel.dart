import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/child/models/child_model.dart';
import 'package:vigil_parents_app/features/child/repo/child_repo.dart';

enum ChildViewState { idle, loading, loaded, error }

class ChildViewModel extends ChangeNotifier {
  ChildViewModel(this._repository);

  final ChildRepository _repository;

  ChildViewState _state = ChildViewState.idle;
  ChildViewState get state => _state;

  List<ChildModel> _children = const [];
  List<ChildModel> get children => _children;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _state == ChildViewState.loading;
  bool get hasError => _state == ChildViewState.error;
  bool get isEmpty => _state == ChildViewState.loaded && _children.isEmpty;

  final Set<String> _deletingIds = <String>{};
  bool isDeleting(String id) => _deletingIds.contains(id);

  final Set<String> _updatingIds = <String>{};
  bool isUpdating(String id) => _updatingIds.contains(id);

  Future<void> loadChildren({bool showLoader = true}) async {
    if (showLoader) {
      _state = ChildViewState.loading;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final list = await _repository.fetchChildren();
      _children = list;
      _state = ChildViewState.loaded;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = ChildViewState.error;
    }

    notifyListeners();
  }

  Future<void> refresh() => loadChildren(showLoader: false);

  Future<void> updateChildName(String childId, String name) async {
    if (_updatingIds.contains(childId)) {
      throw Exception('Update already in progress');
    }
    _updatingIds.add(childId);
    notifyListeners();

    try {
      final updated = await _repository.updateChildName(childId, name);
      _children = [
        for (final c in _children) if (c.id == childId) updated else c,
      ];
    } finally {
      _updatingIds.remove(childId);
      notifyListeners();
    }
  }

  Future<String> deleteChild(String childId) async {
    if (_deletingIds.contains(childId)) {
      throw Exception('Delete already in progress');
    }
    _deletingIds.add(childId);
    notifyListeners();

    try {
      final msg = await _repository.deleteChild(childId);
      _children = _children.where((c) => c.id != childId).toList();
      return msg;
    } finally {
      _deletingIds.remove(childId);
      notifyListeners();
    }
  }
}

final childRepositoryProvider = Provider<ChildRepository>((ref) {
  return ChildRepository();
});

final childViewModelProvider = ChangeNotifierProvider<ChildViewModel>((ref) {
  return ChildViewModel(ref.read(childRepositoryProvider));
});
