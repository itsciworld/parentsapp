import 'package:flutter/material.dart';
import 'package:vigil_parents_app/features/calls/presentation/view_model/view/calls_view.dart';
import 'package:vigil_parents_app/features/gallery/presentations/view/gallery_view.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';
import 'package:vigil_parents_app/features/home/repo/home_repo.dart';
import 'package:vigil_parents_app/features/sms/view/sms_view.dart';

/// UI state phases for the home screen.
enum HomeViewState { loading, loaded, error }

/// ============================================================================
/// HOME VIEW MODEL
/// ----------------------------------------------------------------------------
/// A plain [ChangeNotifier] — no extra packages required. It owns the screen
/// state, talks to the [HomeRepository], and exposes immutable data + intent
/// callbacks to the View.
///
/// Wire it up with whatever you already use (Provider / Riverpod / GetIt /
/// setState). The included `main.dart` uses a tiny ListenableBuilder so it runs
/// with zero external dependencies.
/// ============================================================================
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({HomeRepository? repository})
    : _repository = repository ?? DummyHomeRepository();

  final HomeRepository _repository;

  // --- State ----------------------------------------------------------------
  HomeViewState _state = HomeViewState.loading;
  HomeViewState get state => _state;

  HomeDashboardData? _data;
  HomeDashboardData? get data => _data;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _state == HomeViewState.loading;
  bool get hasError => _state == HomeViewState.error;

  // --- Intents --------------------------------------------------------------

  /// Initial load. Call from `initState`.
  Future<void> init() async {
    await _load();
  }

  /// Pull-to-refresh handler.
  Future<void> refresh() async {
    await _load(showSpinner: false);
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      _state = HomeViewState.loading;
      notifyListeners();
    }
    try {
      _data = await _repository.fetchDashboard();
      _state = HomeViewState.loaded;
      _errorMessage = null;
    } catch (e) {
      _state = HomeViewState.error;
      _errorMessage = 'Could not load dashboard. Pull to retry.';
    }
    notifyListeners();
  }

  // --- Navigation / tap intents (stubbed for now) ---------------------------
  void onFeatureTapped(BuildContext context, FeatureTile tile) {
    switch (tile.id) {
      case 'calls':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AccessCallsScreen()),
        );
        break;

      case 'sms':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SmsScreen()),
        );
        break;

      case 'gallery':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GalleryScreen()),
        );
        break;

      default:
        break;
    }
  }

  void onViewOnMap() {
    debugPrint('View on map tapped');
    // TODO: open the map screen.
  }

  void onViewAllAlerts() {
    debugPrint('View all alerts tapped');
  }

  void onViewInsight() {
    debugPrint('View AI insight tapped');
  }

  void onKnowMoreFoundation() {
    debugPrint('Foundation "Know More" tapped');
  }

  void onNotificationsTapped() {
    debugPrint('Notifications tapped');
  }

  int _bottomNavIndex = 0;
  int get bottomNavIndex => _bottomNavIndex;

  void onBottomNavTapped(int index) {
    _bottomNavIndex = index;
    notifyListeners();
  }
}
