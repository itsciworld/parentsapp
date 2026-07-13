import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/ai_insights/models/ai_insights_model.dart';
import 'package:vigil_parents_app/features/ai_insights/repo/ai_insights_repo.dart';

/// Loads the AI daily-intelligence analysis for the selected child. The
/// analysis is always requested for *today* when the screen opens; there is no
/// background polling — a fresh call happens on open, child switch and
/// pull-to-refresh.
class AiInsightsViewModel extends ChangeNotifier {
  AiInsightsViewModel(this._repository);

  final AiInsightsRepository _repository;

  AiAnalysisResponse? data;
  bool loading = false;
  String? error;

  /// The child the current [data] belongs to.
  String? _childId;
  String? get childId => _childId;

  /// The date the current [data] was requested for (YYYY-MM-DD).
  String _date = AiInsightsRepository.formatDate(DateTime.now());
  String get date => _date;

  DailyIntelligence? get intelligence => data?.intelligence;

  Future<void> load(String childId, {bool showLoader = true}) async {
    if (_childId != childId) {
      data = null;
      error = null;
    }
    _childId = childId;
    _date = AiInsightsRepository.formatDate(DateTime.now());

    if (showLoader) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      final res = await _repository.analyze(childId: childId, date: _date);
      if (_childId != childId) return; // selection changed mid-flight
      data = res;
      error = null;
    } catch (e) {
      if (_childId != childId) return;
      error = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (_childId == childId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  /// Re-runs the analysis for the current child (pull-to-refresh / retry).
  Future<void> refresh({bool showLoader = false}) async {
    final id = _childId;
    if (id == null) return;
    await load(id, showLoader: showLoader);
  }

  /// Fetches the daily PDF report bytes for the currently loaded child/date.
  Future<Uint8List> fetchReport() async {
    final id = _childId;
    if (id == null) throw Exception('No child selected');
    return _repository.downloadDailyReport(childId: id, date: _date);
  }
}

final aiInsightsRepositoryProvider = Provider<AiInsightsRepository>((ref) {
  return AiInsightsRepository();
});

final aiInsightsViewModelProvider =
    ChangeNotifierProvider<AiInsightsViewModel>((ref) {
      return AiInsightsViewModel(ref.read(aiInsightsRepositoryProvider));
    });
