import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vigil_parents_app/core/services/child_context/child_context_resolver.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

import '../models/app_usage_model.dart';

/// Identifiers needed to query app usage for a child.
typedef AppUsageContext = ChildContext;

class AppUsageRepository {
  AppUsageRepository({ApiClient? client}) : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  /// See [ChildContextResolver.resolve] — shared across features and
  /// cached, so polling callers no longer re-fetch the children list.
  Future<AppUsageContext> resolveContext() => ChildContextResolver.resolve();

  /// GET /api/apps/get_apps — the child's tracked apps, sorted by usage time
  /// (most-used first). `x-device-key` is attached automatically by
  /// [ApiInterceptor].
  Future<List<AppUsage>> getApps({
    required String childId,
    String? parentId,
    int page = 1,
    int limit = 20,
  }) async {
    final pid = parentId ?? await SecureDeviceService.getParentId() ?? '';
    final query = {
      'child_id': childId,
      'parent_id': pid,
      'page': page,
      'limit': limit,
    };

    if (kDebugMode) {
      print('➡️  [AppUsage] GET /api/apps/get_apps (today)');
      print('    query: $query');
    }

    try {
      final response = await _apiClient.get('/api/apps/get_apps', query: query);

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final parsed = AppUsageResponse.fromJson(data);
        final apps = parsed.apps
          ..sort((a, b) => b.usageMinutes.compareTo(a.usageMinutes));
        if (kDebugMode) {
          print(
            '✅  [AppUsage] get_apps → ${apps.length} apps, '
            'total ${parsed.totalScreenTimeMinutes}m',
          );
        }
        return apps;
      }
      if (kDebugMode) print('⚠️  [AppUsage] get_apps → unexpected response');
      return const [];
    } on DioException catch (e) {
      if (kDebugMode) print('❌  [AppUsage] get_apps failed: ${e.error}');
      throw Exception(e.error.toString());
    } catch (e) {
      if (kDebugMode) print('❌  [AppUsage] get_apps failed: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// GET /api/apps/history — the child's app usage history for a preset
  /// period (`yesterday`, `3days`, `7days`). Returns apps sorted by usage time
  /// (most-used first). The response shape matches `/api/apps/get_apps`.
  Future<List<AppUsage>> getAppHistory({
    required String childId,
    String? parentId,
    required String period,
    int page = 1,
    int limit = 200,
  }) async {
    final pid = parentId ?? await SecureDeviceService.getParentId() ?? '';
    final query = {
      'child_id': childId,
      'parent_id': pid,
      'period': period,
      'page': page,
      'limit': limit,
    };

    if (kDebugMode) {
      print('➡️  [AppUsage] GET /api/apps/history (period=$period)');
      print('    query: $query');
    }

    try {
      final response = await _apiClient.get('/api/apps/history', query: query);

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final parsed = AppUsageResponse.fromJson(data);
        final apps = parsed.apps
          ..sort((a, b) => b.usageMinutes.compareTo(a.usageMinutes));
        if (kDebugMode) {
          print(
            '✅  [AppUsage] history($period) → ${apps.length} apps, '
            'total ${parsed.totalScreenTimeMinutes}m',
          );
        }
        return apps;
      }
      if (kDebugMode) print('⚠️  [AppUsage] history → unexpected response');
      return const [];
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌  [AppUsage] history($period) failed: ${e.error}');
      }
      throw Exception(e.error.toString());
    } catch (e) {
      if (kDebugMode) print('❌  [AppUsage] history($period) failed: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
