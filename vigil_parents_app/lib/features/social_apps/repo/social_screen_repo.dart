import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/core/utils/history_window.dart';
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
    int days = kSocialHistoryDays,
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
      if (data is Map) {
        final parsed = SocialScreenResponse.fromJson(
          Map<String, dynamic>.from(data),
        );
        if (kDebugMode) {
          print(
            '✅  [SocialScreen] ${parsed.apps.length} apps, '
            '${parsed.totalMessages} messages',
          );
          for (final a in parsed.apps) {
            print(
              '    • ${a.app} (${a.package}) — '
              '${a.threads.length} threads, ${a.count} messages',
            );
          }
          // Parsing to nothing is the failure that used to be invisible: the
          // screen showed "no messages" whether the server sent an empty body
          // or a shape we failed to read. Print what actually came back so the
          // two can be told apart at a glance.
          if (parsed.apps.isEmpty) {
            print(
              '⚠️  [SocialScreen] parsed 0 apps — top-level keys: '
              '${data.keys.toList()}',
            );
            print('    raw body: $data');
          } else if (parsed.apps.every((a) => a.threads.isEmpty)) {
            // Apps came through but carried no conversations. That means the
            // per-app object nests its messages under a key this parser
            // doesn't read, so dump one app's shape rather than leaving the
            // screen on a bare "no messages".
            final rawApps = data['apps'];
            final first = rawApps is List && rawApps.isNotEmpty
                ? rawApps.first
                : null;
            print(
              '⚠️  [SocialScreen] apps parsed but every one has 0 threads — '
              'first app keys: ${first is Map ? first.keys.toList() : first}',
            );
            print('    raw first app: $first');
          }
        }
        return parsed;
      }
      if (kDebugMode) {
        print('⚠️  [SocialScreen] unexpected body type: ${data.runtimeType}');
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
