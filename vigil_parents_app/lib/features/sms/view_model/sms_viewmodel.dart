import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/sms/models/sms_thread_model.dart';
import 'package:vigil_parents_app/features/sms/repo/sms_repo.dart';

/// Drives the thread-based SMS screen: loads grouped threads for the selected
/// child and exposes a search filter.
class SmsViewModel extends ChangeNotifier {
  final SmsRepository repository;

  SmsViewModel(this.repository);

  List<SmsThread> _threads = [];
  bool loading = false;
  String? error;
  String _query = '';

  String get query => _query;

  /// Threads after applying the current search query (by address or any
  /// message body within the thread).
  List<SmsThread> get threads {
    if (_query.trim().isEmpty) return _threads;
    final q = _query.toLowerCase();
    return _threads
        .where(
          (t) =>
              t.address.toLowerCase().contains(q) ||
              t.messages.any((m) => m.body.toLowerCase().contains(q)),
        )
        .toList();
  }

  int get totalThreads => _threads.length;
  int get totalMessages => _threads.fold(0, (sum, t) => sum + t.count);

  Future<void> loadThreads({bool showLoader = true}) async {
    if (showLoader) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      final ctx = await repository.resolveContext();
      if (!ctx.isValid) {
        _threads = [];
        error = ctx.childId.isEmpty
            ? 'No child linked to this account yet'
            : 'Missing account information';
      } else {
        _threads = await repository.getThreads(
          childId: ctx.childId,
          parentId: ctx.parentId,
        );
        error = null;
      }
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  /// Reloads from scratch — used when the selected child changes.
  Future<void> reload() async {
    _threads = [];
    await loadThreads();
  }

  Future<void> refresh() => loadThreads(showLoader: false);
}

final smsViewModelProvider = ChangeNotifierProvider((ref) {
  return SmsViewModel(SmsRepository());
});
