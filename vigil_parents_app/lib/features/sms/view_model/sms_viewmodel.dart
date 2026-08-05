import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigil_parents_app/core/utils/refresh_guard.dart';
import 'package:vigil_parents_app/components/day_window_selector.dart';
import 'package:vigil_parents_app/features/sms/models/sms_thread_model.dart';
import 'package:vigil_parents_app/features/sms/repo/sms_repo.dart';

/// Drives the thread-based SMS screen: loads grouped threads for the selected
/// child and exposes a search filter. Tracks a per-thread "seen" count so the
/// thread badge behaves like an unread counter that clears once opened.
class SmsViewModel extends ChangeNotifier with RefreshGuard {
  final SmsRepository repository;

  SmsViewModel(this.repository);

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  List<SmsThread> _threads = [];
  bool loading = false;
  String? error;
  String _query = '';
  DayWindow _window = DayWindow.all;

  // threadId -> message count already viewed. Loaded per child.
  Map<String, int> _seen = {};
  String _childId = '';

  String get query => _query;
  DayWindow get activeWindow => _window;

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

  /// Threads after applying the active day window (by last activity) and the
  /// current search query (by address or any message body within the thread).
  List<SmsThread> get threads {
    var list = _threads;
    if (_window != DayWindow.all) {
      list = list.where((t) => _window.includes(t.lastMessageAt)).toList();
    }
    if (_query.trim().isEmpty) return list;
    final q = _query.toLowerCase();
    return list
        .where(
          (t) =>
              t.address.toLowerCase().contains(q) ||
              t.messages.any((m) => m.body.toLowerCase().contains(q)),
        )
        .toList();
  }

  /// Threads loaded for this child before any filtering. The empty state uses
  /// it to tell "this child has no SMS" apart from "the filter hid them all".
  int get loadedThreads => _threads.length;

  /// The counters above the list describe *the list*. Reading the unfiltered
  /// data here is what put "48 Chats · 155 Messages" on top of an empty screen
  /// and made the filter look broken.
  int get totalThreads => threads.length;

  int get totalMessages =>
      threads.fold(0, (sum, t) => sum + _messagesInWindow(t));

  /// Messages in [thread] that fall inside the active window. With no window
  /// the server's own count wins — it covers messages beyond the ones this
  /// payload expanded.
  int _messagesInWindow(SmsThread thread) {
    if (_window == DayWindow.all) return thread.count;
    return thread.messages.where((m) => _window.includes(m.date)).length;
  }

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

  void setWindow(DayWindow window) {
    if (_window == window) return;
    _window = window;
    notifyListeners();
  }

  /// Reloads from scratch — used when the selected child changes.
  Future<void> reload() async {
    _threads = [];
    await loadThreads();
  }

  Future<void> refresh() =>
      guardedRefresh(() => loadThreads(showLoader: false));
}

final smsViewModelProvider = ChangeNotifierProvider((ref) {
  return SmsViewModel(SmsRepository());
});
