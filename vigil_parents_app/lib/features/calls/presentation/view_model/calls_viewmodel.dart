import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/calls/models/calls_model.dart';
import 'package:vigil_parents_app/features/calls/repo/call_repo.dart';

enum CallFilter { all, incoming, outgoing, missed }

class CallLogViewModel extends ChangeNotifier {
  final CallLogRepository repository;

  CallLogViewModel({CallLogRepository? repository})
    : repository = repository ?? CallLogRepository();

  // Large limit so a single request returns the whole log set.
  static const int _allLimit = 1000;

  List<CallLogModel> _all = [];
  bool loading = false;
  String? error;
  String _query = '';
  CallFilter _filter = CallFilter.all;

  String get query => _query;
  CallFilter get activeFilter => _filter;

  /// Summary counts computed from the full (unfiltered) set.
  CallSummaryModel get summary => CallSummaryModel.fromLogs(_all);
  int get missedCallCount => summary.missedCalls;

  /// Logs after applying the active filter + search query, newest first.
  List<CallLogModel> get logs {
    var list = _all;
    if (_filter != CallFilter.all) {
      final type = switch (_filter) {
        CallFilter.incoming => CallType.incoming,
        CallFilter.outgoing => CallType.outgoing,
        CallFilter.missed => CallType.missed,
        CallFilter.all => null,
      };
      if (type != null) list = list.where((l) => l.callType == type).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (l) =>
                l.name.toLowerCase().contains(q) ||
                l.number.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  bool get isEmpty => logs.isEmpty;

  /// Filtered logs grouped by a date label (Today / Yesterday / d Mon yyyy).
  Map<String, List<CallLogModel>> get groupedLogs {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final grouped = <String, List<CallLogModel>>{};
    for (final log in logs) {
      final ts = log.timestamp;
      String label;
      if (ts == null) {
        label = 'Unknown date';
      } else {
        final day = DateTime(ts.year, ts.month, ts.day);
        if (day == today) {
          label = 'Today';
        } else if (day == yesterday) {
          label = 'Yesterday';
        } else {
          label = '${ts.day} ${_month(ts.month)} ${ts.year}';
        }
      }
      grouped.putIfAbsent(label, () => []).add(log);
    }
    return grouped;
  }

  static String _month(int m) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[m];
  }

  Future<void> loadCallLogs({bool showLoader = true}) async {
    if (showLoader) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      final ctx = await repository.resolveContext();
      if (!ctx.isValid) {
        _all = [];
        error = ctx.childId.isEmpty
            ? 'No child linked to this account yet'
            : 'Missing account information';
      } else {
        final res = await repository.getCallLogs(
          childId: ctx.childId,
          parentId: ctx.parentId,
          page: 1,
          limit: _allLimit,
        );
        final list = res.callLogs;
        // Newest first.
        list.sort((a, b) {
          final ad = a.timestamp, bd = b.timestamp;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });
        _all = list;
        error = null;
      }
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setFilter(CallFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  /// Reloads from scratch — used when the selected child changes.
  Future<void> reload() async {
    _all = [];
    await loadCallLogs();
  }

  Future<void> refresh() => loadCallLogs(showLoader: false);
}

final callLogViewModelProvider = ChangeNotifierProvider((ref) {
  return CallLogViewModel();
});
