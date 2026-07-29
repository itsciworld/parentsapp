import 'package:dio/dio.dart';
import 'package:vigil_parents_app/features/subscription/models/subscription_model.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

/// Talks to the subscription + payment endpoints. The auth token and (when
/// relevant) the selected child's device key are attached automatically by
/// [ApiInterceptor], so these methods only deal with paths and payloads.
class SubscriptionRepository {
  SubscriptionRepository({ApiClient? client})
    : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  /// `GET /api/subscriptions/plans` — public, returns every active plan.
  Future<List<SubscriptionPlan>> getPlans() async {
    try {
      final response = await _apiClient.get('/api/subscriptions/plans');
      final data = response.data;

      final rawPlans = data is Map ? data['plans'] : data;
      if (rawPlans is! List) {
        throw Exception('Invalid plans response');
      }

      return rawPlans
          .whereType<Map>()
          .map((e) => SubscriptionPlan.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.isActive)
          .toList();
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// `GET /api/subscriptions/my` — the caller's current subscription state.
  Future<MySubscription> getMySubscription() async {
    try {
      final response = await _apiClient.get('/api/subscriptions/my');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return MySubscription.fromJson(data);
      }
      if (data is Map) {
        return MySubscription.fromJson(Map<String, dynamic>.from(data));
      }
      return MySubscription.none;
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// `POST /api/payments/initiate` — the recommended purchase path (same one
  /// the parent web app uses). Returns the Stripe Checkout session to open.
  Future<CheckoutSession> initiatePayment({
    required String planId,
    required String email,
    required String name,
    String? couponCode,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/payments/initiate',
        data: {
          'planId': planId,
          'email': email,
          'name': name,
          if (couponCode != null && couponCode.trim().isNotEmpty)
            'couponCode': couponCode.trim(),
        },
      );
      return _sessionFrom(response.data);
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// `POST /api/subscriptions/upgrade` — for a parent who already has a paid
  /// plan and moves to a higher one. Returns a Checkout session for the
  /// prorated amount.
  Future<CheckoutSession> upgrade(String newPlanId) async {
    try {
      final response = await _apiClient.post(
        '/api/subscriptions/upgrade',
        data: {'newPlanId': newPlanId},
      );
      return _sessionFrom(response.data);
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// `POST /api/subscriptions/downgrade` — applied at the next billing cycle,
  /// so there's no payment step.
  Future<void> downgrade(String newPlanId) async {
    try {
      await _apiClient.post(
        '/api/subscriptions/downgrade',
        data: {'newPlanId': newPlanId},
      );
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// `POST /api/subscriptions/cancel` — turns auto-renew off; access remains
  /// until the current expiry date.
  Future<void> cancel() async {
    try {
      await _apiClient.post('/api/subscriptions/cancel');
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  CheckoutSession _sessionFrom(dynamic data) {
    if (data is Map) {
      final session = CheckoutSession.fromJson(Map<String, dynamic>.from(data));
      if (session.url.isEmpty) {
        throw Exception('No checkout URL returned');
      }
      return session;
    }
    throw Exception('Invalid payment response');
  }
}
