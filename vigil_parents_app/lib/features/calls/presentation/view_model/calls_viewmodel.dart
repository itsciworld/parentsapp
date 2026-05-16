import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/calls/models/calls_model.dart';
import 'package:vigil_parents_app/features/calls/repo/call_repo.dart';

enum FilterTab { all, incoming, outgoing, missed }

class CallLogViewModel extends ChangeNotifier {
  final CallLogRepository _repository;

  CallLogViewModel({CallLogRepository? repository})
    : _repository = repository ?? CallLogRepositoryImpl();

  // State
  bool _isLoading = false;
  String? _errorMessage;
  List<CallLogModel> _callLogs = [];
  CallSummaryModel? _summary;
  List<ChildModel> _children = [];
  ChildModel? _selectedChild;
  DateTime _selectedDate = DateTime(2025, 5, 21);
  FilterTab _activeFilter = FilterTab.all;
  String _searchQuery = '';

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  CallSummaryModel? get summary => _summary;
  List<ChildModel> get children => _children;
  ChildModel? get selectedChild => _selectedChild;
  DateTime get selectedDate => _selectedDate;
  FilterTab get activeFilter => _activeFilter;
  String get searchQuery => _searchQuery;

  int get missedCallCount => _summary?.missedCalls ?? 0;

  /// Groups call logs by date label (Today / Yesterday / date string)
  Map<String, List<CallLogModel>> get groupedCallLogs {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<CallLogModel>> grouped = {};

    for (final log in _callLogs) {
      final logDay = DateTime(
        log.callTime.year,
        log.callTime.month,
        log.callTime.day,
      );
      String label;
      if (logDay == today || logDay == DateTime(2025, 5, 21)) {
        label = 'Today, 21 May 2025';
      } else if (logDay == yesterday || logDay == DateTime(2025, 5, 20)) {
        label = 'Yesterday, 20 May 2025';
      } else {
        label = '${logDay.day} ${_monthName(logDay.month)} ${logDay.year}';
      }
      grouped.putIfAbsent(label, () => []).add(log);
    }

    return grouped;
  }

  String _monthName(int month) {
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
    return months[month];
  }

  // Actions

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      _children = await _repository.getChildren();
      _selectedChild = _children.isNotEmpty ? _children.first : null;
      await _loadData();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadData() async {
    if (_selectedChild == null) return;
    _errorMessage = null;

    final callType = _filterTabToCallType(_activeFilter);

    final results = await Future.wait([
      _repository.getCallLogs(
        childId: _selectedChild!.id,
        date: _selectedDate,
        filterType: callType,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      ),
      _repository.getCallSummary(
        childId: _selectedChild!.id,
        date: _selectedDate,
      ),
    ]);

    _callLogs = results[0] as List<CallLogModel>;
    _summary = results[1] as CallSummaryModel;
  }

  CallType? _filterTabToCallType(FilterTab tab) {
    switch (tab) {
      case FilterTab.incoming:
        return CallType.incoming;
      case FilterTab.outgoing:
        return CallType.outgoing;
      case FilterTab.missed:
        return CallType.missed;
      case FilterTab.all:
        return null;
    }
  }

  Future<void> setFilter(FilterTab tab) async {
    if (_activeFilter == tab) return;
    _activeFilter = tab;
    _isLoading = true;
    notifyListeners();
    try {
      await _loadData();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSearchQuery(String query) async {
    _searchQuery = query;
    _isLoading = true;
    notifyListeners();
    try {
      await _loadData();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectChild(ChildModel child) async {
    _selectedChild = child;
    _isLoading = true;
    notifyListeners();
    try {
      await _loadData();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectDate(DateTime date) async {
    _selectedDate = date;
    _isLoading = true;
    notifyListeners();
    try {
      await _loadData();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _loadData();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

final callLogViewModelProvider = ChangeNotifierProvider((ref) {
  return CallLogViewModel();
});
