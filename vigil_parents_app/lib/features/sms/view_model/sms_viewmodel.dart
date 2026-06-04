import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/sms/models/sms_model.dart';
import 'package:vigil_parents_app/features/sms/repo/sms_repo.dart';

class SmsViewModel extends ChangeNotifier {
  final SmsRepository repository;

  SmsViewModel(this.repository);

  static const int pageSize = 20;

  List<SmsModel> _all = [];
  bool loading = false;
  bool loadingMore = false;
  String? error;
  int total = 0;
  int _limit = pageSize;
  String _query = '';

  String get query => _query;

  /// Messages after applying the current search query.
  List<SmsModel> get messages {
    if (_query.trim().isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all
        .where(
          (m) =>
              m.name.toLowerCase().contains(q) ||
              m.phone.toLowerCase().contains(q) ||
              m.message.toLowerCase().contains(q),
        )
        .toList();
  }

  /// More messages exist on the server than we've loaded.
  bool get hasMore => _query.trim().isEmpty && _all.length < total;

  int get unknownCount => _all.where((m) => m.isUnknown).length;

  Future<void> loadMessages({bool showLoader = true}) async {
    if (showLoader) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      final ctx = await repository.resolveContext();
      if (!ctx.isValid) {
        _all = [];
        total = 0;
        error = ctx.childId.isEmpty
            ? 'No child linked to this account yet'
            : 'Missing account information';
      } else {
        // page=1 with a growing limit keeps the list stable across the 5s
        // auto-refresh while still letting the user load more.
        final res = await repository.getSms(
          childId: ctx.childId,
          parentId: ctx.parentId,
          page: 1,
          limit: _limit,
        );
        _all = res.messages;
        total = res.total;
        error = null;
      }
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Loads the next window of messages.
  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();

    _limit += pageSize;
    await loadMessages(showLoader: false);

    loadingMore = false;
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  /// Reloads from scratch — used when the selected child changes. Resets the
  /// page window and clears the current list so the new child's messages
  /// replace the old ones immediately.
  Future<void> reload() async {
    _limit = pageSize;
    _all = [];
    await loadMessages();
  }

  Future<void> refresh() => loadMessages(showLoader: false);
}

final smsViewModelProvider = ChangeNotifierProvider((ref) {
  return SmsViewModel(SmsRepository());
});
