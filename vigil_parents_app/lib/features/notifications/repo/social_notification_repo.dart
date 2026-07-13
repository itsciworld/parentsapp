import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

import '../models/social_notification_model.dart';

class SocialNotificationRepository {
  SocialNotificationRepository({ApiClient? client})
    : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  /// GET /api/social/notifications — social-app notifications for a child,
  /// grouped per app. `x-device-key` is attached automatically by
  /// [ApiInterceptor].
  Future<SocialNotificationsResponse> getNotifications({
    required String childId,
    String? parentId,
    int limit = 200,
    int days = 2,
  }) async {
    final pid = parentId ?? await SecureDeviceService.getParentId() ?? '';
    final query = {
      'child_id': childId,
      'parent_id': pid,
      'days': days,
      'limit': limit,
    };

    if (kDebugMode) {
      print('➡️  [Notifications] GET /api/social/notifications');
      print('    query: $query');
    }

    try {
      final response = await _apiClient.get(
        '/api/social/notifications',
        query: query,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final parsed = SocialNotificationsResponse.fromJson(data);
        if (kDebugMode) {
          print(
            '✅  [Notifications] ${parsed.apps.length} apps, '
            '${parsed.totalMessages} messages',
          );
        }
        return parsed;
      }
      return const SocialNotificationsResponse(
        total: 0,
        totalMessages: 0,
        windowSince: null,
        apps: [],
      );
    } on DioException catch (e) {
      if (kDebugMode) print('❌  [Notifications] failed: ${e.error}');
      throw Exception(e.error.toString());
    } catch (e) {
      if (kDebugMode) print('❌  [Notifications] failed: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
