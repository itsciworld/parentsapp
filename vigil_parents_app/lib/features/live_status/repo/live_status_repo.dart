import 'package:dio/dio.dart';
import 'package:vigil_parents_app/core/services/child_context/child_context_resolver.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

import '../models/live_status_model.dart';

/// Identifier needed to query the live status for a child.
typedef LiveStatusContext = ChildContext;

class LiveStatusRepository {
  LiveStatusRepository({ApiClient? client})
    : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  /// See [ChildContextResolver.resolve] — shared across features and
  /// cached, so polling callers no longer re-fetch the children list.
  Future<LiveStatusContext> resolveContext() => ChildContextResolver.resolve();

  /// GET /api/children/{childId}/live-status
  ///
  /// The bearer token is attached automatically by [ApiInterceptor].
  Future<LiveStatusResponse> fetchLiveStatus(String childId) async {
    try {
      final response = await _apiClient.get(
        '/api/children/$childId/live-status',
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return LiveStatusResponse.fromJson(data);
      }
      throw Exception('Invalid live-status response');
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
