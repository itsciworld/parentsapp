import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

import '../models/social_screen_model.dart';

class SocialScreenRepository {
  SocialScreenRepository({ApiClient? client})
    : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  /// GET /api/social/screen — captured chat messages for a child, grouped per
  /// app. `x-device-key` is attached automatically by [ApiInterceptor].
  Future<SocialScreenResponse> getScreenMessages({
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
      print('➡️  [SocialScreen] GET /api/social/screen');
      print('    query: $query');
    }

    try {
      final response = await _apiClient.get('/api/social/screen', query: query);

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final parsed = SocialScreenResponse.fromJson(data);
        if (kDebugMode) {
          print(
            '✅  [SocialScreen] ${parsed.apps.length} apps, '
            '${parsed.totalMessages} messages',
          );
        }
        return parsed;
      }
      return const SocialScreenResponse(
        total: 0,
        totalMessages: 0,
        windowSince: null,
        apps: [],
      );
    } on DioException catch (e) {
      if (kDebugMode) print('❌  [SocialScreen] failed: ${e.error}');
      throw Exception(e.error.toString());
    } catch (e) {
      if (kDebugMode) print('❌  [SocialScreen] failed: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
