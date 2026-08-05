import 'package:dio/dio.dart';
import 'package:vigil_parents_app/core/services/child_context/child_context_resolver.dart';
import 'package:vigil_parents_app/features/calls/models/calls_model.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

/// Identifiers needed to query call logs for a child.
typedef CallContext = ChildContext;

class CallLogRepository {
  CallLogRepository({ApiClient? client}) : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  /// See [ChildContextResolver.resolve] — shared across features and
  /// cached, so polling callers no longer re-fetch the children list.
  Future<CallContext> resolveContext() => ChildContextResolver.resolve();

  /// GET /api/logs/calllogs — paginated. `x-device-key` (selected child's
  /// device key) is attached automatically by ApiInterceptor.
  Future<CallLogsResponse> getCallLogs({
    required String childId,
    required String parentId,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/logs/calllogs',
        query: {
          'child_id': childId,
          'parent_id': parentId,
          'page': page,
          'limit': limit,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return CallLogsResponse.fromJson(data);
      }
      return const CallLogsResponse(
        status: 200,
        total: 0,
        page: 1,
        limit: 100,
        pages: 0,
        callLogs: [],
      );
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
