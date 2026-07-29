import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/subscription/models/subscription_model.dart';
import 'package:vigil_parents_app/features/subscription/repo/subscription_repo.dart';

enum SubscriptionState { idle, loading, loaded, error }

/// Owns the subscription screen state: the plan catalogue, the parent's
/// current subscription, and the checkout call. UI reads plans + [mySubscription]
/// and drives the purchase through [startCheckout].
class SubscriptionViewModel extends ChangeNotifier {
  SubscriptionViewModel(this._repository);

  final SubscriptionRepository _repository;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  SubscriptionState _state = SubscriptionState.idle;
  SubscriptionState get state => _state;
  bool get isLoading => _state == SubscriptionState.loading;
  bool get hasError => _state == SubscriptionState.error;

  List<SubscriptionPlan> _plans = const [];
  List<SubscriptionPlan> get plans => _plans;

  MySubscription _mySubscription = MySubscription.none;
  MySubscription get mySubscription => _mySubscription;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// The plan currently being checked out (so its card can show a spinner
  /// while the rest stay tappable-disabled).
  String? _checkoutPlanId;
  String? get checkoutPlanId => _checkoutPlanId;
  bool get isCheckingOut => _checkoutPlanId != null;

  /// Loads the plan catalogue and the parent's subscription together. The
  /// my-subscription call is best-effort — a signed-out or errored state there
  /// must not blank out the plan list.
  Future<void> load({bool showLoader = true}) async {
    if (showLoader) {
      _state = SubscriptionState.loading;
      _errorMessage = null;
      _notify();
    }

    try {
      final results = await Future.wait([
        _repository.getPlans(),
        _repository.getMySubscription().catchError(
          (_) => MySubscription.none,
        ),
      ]);
      _plans = results[0] as List<SubscriptionPlan>;
      _mySubscription = results[1] as MySubscription;
      _state = SubscriptionState.loaded;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = SubscriptionState.error;
    }
    _notify();
  }

  Future<void> refresh() => load(showLoader: false);

  /// Reloads only the current-subscription state — used after returning from
  /// checkout, where the webhook may have just activated the plan.
  Future<void> refreshMySubscription() async {
    try {
      _mySubscription = await _repository.getMySubscription();
      _notify();
    } catch (_) {
      // Keep the last known state; the caller can retry.
    }
  }

  /// Whether [plan] is the parent's active plan right now. Matches on plan id
  /// first (most reliable), then plan type, then falls back to a name
  /// comparison — because `/subscriptions/my` and `/subscriptions/plans` can
  /// return slightly different display names for the same plan.
  bool isCurrentPlan(SubscriptionPlan plan) {
    if (!_mySubscription.hasSubscription) return false;
    final subId = _mySubscription.planId.trim();
    if (subId.isNotEmpty && plan.id.trim().isNotEmpty) {
      return subId == plan.id.trim();
    }
    final subType = _mySubscription.planType.trim().toLowerCase();
    if (subType.isNotEmpty && plan.type.trim().isNotEmpty) {
      return subType == plan.type.trim().toLowerCase();
    }
    return _mySubscription.planName.trim().toLowerCase() ==
        plan.name.trim().toLowerCase();
  }

  /// The most expensive plan on offer — the "top" tier there's nothing above.
  SubscriptionPlan? get topPlan {
    if (_plans.isEmpty) return null;
    final sorted = [..._plans]..sort((a, b) => b.price.compareTo(a.price));
    return sorted.first;
  }

  /// The parent's active plan, resolved back to the catalogue entry (so we can
  /// read its price, which `/subscriptions/my` doesn't return). Matches by id
  /// first, then by name.
  SubscriptionPlan? get currentPlan {
    if (!_mySubscription.hasSubscription) return null;
    final subId = _mySubscription.planId.trim();
    if (subId.isNotEmpty) {
      for (final p in _plans) {
        if (p.id.trim() == subId) return p;
      }
    }
    final type = _mySubscription.planType.trim().toLowerCase();
    if (type.isNotEmpty) {
      for (final p in _plans) {
        if (p.type.trim().toLowerCase() == type) return p;
      }
    }
    final name = _mySubscription.planName.trim().toLowerCase();
    for (final p in _plans) {
      if (p.name.trim().toLowerCase() == name) return p;
    }
    return null;
  }

  /// True when the parent already holds the highest-priced (paid) plan, so
  /// there is nothing left to upgrade to. Trial never counts as "top".
  bool get isOnTopPlan {
    final top = topPlan;
    final current = currentPlan;
    if (top == null || current == null) return false;
    if (top.isFree) return false; // no paid tier exists at all
    if (_mySubscription.inTrial) return false;
    return current.price >= top.price;
  }

  /// True while a cancel/deactivate request is in flight.
  bool _canceling = false;
  bool get isCanceling => _canceling;

  /// Turns off auto-renew via `POST /api/subscriptions/cancel`. Access stays
  /// until the current expiry date. Refreshes the subscription so the UI
  /// reflects the new (non-renewing) state. Throws with a friendly message.
  Future<void> cancelSubscription() async {
    _canceling = true;
    _notify();
    try {
      await _repository.cancel();
      await refreshMySubscription();
    } finally {
      _canceling = false;
      _notify();
    }
  }

  /// Starts a Stripe Checkout session for [plan] and returns its URL for the
  /// caller to open in the WebView. Throws with a friendly message on failure.
  Future<CheckoutSession> startCheckout({
    required SubscriptionPlan plan,
    required String email,
    required String name,
    String? couponCode,
  }) async {
    _checkoutPlanId = plan.id;
    _notify();
    try {
      final session = await _repository.initiatePayment(
        planId: plan.id,
        email: email,
        name: name,
        couponCode: couponCode,
      );
      return session;
    } finally {
      _checkoutPlanId = null;
      _notify();
    }
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

final subscriptionViewModelProvider =
    ChangeNotifierProvider<SubscriptionViewModel>((ref) {
      return SubscriptionViewModel(ref.read(subscriptionRepositoryProvider));
    });
