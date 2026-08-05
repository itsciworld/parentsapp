import 'package:dio/dio.dart';
import 'package:vigil_parents_app/core/services/child_context/child_context_resolver.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

import '../models/sms_model.dart';
import '../models/sms_thread_model.dart';

/// Identifiers needed to query SMS for a child.
typedef SmsContext = ChildContext;

class SmsRepository {
  SmsRepository({ApiClient? client}) : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  /// See [ChildContextResolver.resolve] — shared with every other feature and
  /// cached, so the 5s poll on this screen no longer re-fetches the children
  /// list on each tick.
  Future<SmsContext> resolveContext() => ChildContextResolver.resolve();

  /// Thread-grouped SMS for a child. One call returns every thread with its
  /// full message list and count — powering both the thread list and the
  /// conversation view. `x-device-key` is attached by ApiInterceptor.
  Future<List<SmsThread>> getThreads({
    required String childId,
    required String parentId,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/sms/get_sms',
        query: {'child_id': childId, 'parent_id': parentId, 'grouped': true},
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return SmsThreadsResponse.fromJson(data).threads;
      }
      return const [];
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<SmsResponse> getSms({
    required String childId,
    required String parentId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/sms/get_sms',
        query: {
          'child_id': childId,
          'parent_id': parentId,
          'page': page,
          'limit': limit,
        },
        // `x-device-key` is attached automatically by ApiInterceptor from the
        // selected child's stored device key.
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return SmsResponse.fromJson(data);
      }
      return const SmsResponse(
        status: 200,
        total: 0,
        page: 1,
        limit: 20,
        pages: 0,
        messages: [],
      );
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
