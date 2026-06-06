import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigil_parents_app/features/sms/models/sms_thread_model.dart';
import 'package:vigil_parents_app/features/sms/repo/sms_repo.dart';

/// Drives the thread-based SMS screen: loads grouped threads for the selected
/// child and exposes a search filter. Tracks a per-thread "seen" count so the
/// thread badge behaves like an unread counter that clears once opened.
class SmsViewModel extends ChangeNotifier {
  final SmsRepository repository;

  SmsViewModel(this.repository);

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  List<SmsThread> _threads = [];
  bool loading = false;
  String? error;
  String _query = '';

  // threadId -> message count already viewed. Loaded per child.
  Map<String, int> _seen = {};
  String _childId = '';

  String get query => _query;

  static String _seenKey(String childId) => 'sms_thread_seen_$childId';

  /// Unread messages in a thread (count minus what's already been viewed).
  int unreadFor(SmsThread thread) {
    final seen = _seen['${thread.threadId}'] ?? 0;
    final n = thread.count - seen;
    return n > 0 ? n : 0;
  }

  /// Marks a thread as fully read (clears its badge) and persists it.
  Future<void> markThreadSeen(SmsThread thread) async {
    if (_seen['${thread.threadId}'] == thread.count) return;
    _seen['${thread.threadId}'] = thread.count;
    if (_childId.isNotEmpty) {
      await _prefs.setString(_seenKey(_childId), jsonEncode(_seen));
    }
    notifyListeners();
  }

  Future<void> _loadSeen(String childId) async {
    _childId = childId;
    final raw = await _prefs.getString(_seenKey(childId));
    if (raw == null || raw.isEmpty) {
      _seen = {};
      return;
    }
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _seen = m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      _seen = {};
    }
  }

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
        // Load the per-thread "seen" map when the child changes.
        if (_childId != ctx.childId) {
          await _loadSeen(ctx.childId);
        }
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
