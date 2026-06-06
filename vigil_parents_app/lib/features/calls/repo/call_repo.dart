import 'package:dio/dio.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/features/calls/models/calls_model.dart';
import 'package:vigil_parents_app/features/child/repo/child_repo.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

/// Identifiers needed to query call logs for a child.
class CallContext {
  final String parentId;
  final String childId;
  const CallContext({required this.parentId, required this.childId});

  bool get isValid => parentId.isNotEmpty && childId.isNotEmpty;
}

class CallLogRepository {
  CallLogRepository({ApiClient? client, ChildRepository? childRepository})
    : _apiClient = client ?? ApiClient(),
      _childRepository = childRepository ?? ChildRepository();

  final ApiClient _apiClient;
  final ChildRepository _childRepository;

  /// Resolves the parent + child ids from storage. If no child is selected
  /// yet, it fetches the children list, picks the first, and remembers it
  /// (id + device key) so the background service can run headless.
  Future<CallContext> resolveContext() async {
    // No session → don't hit the API (avoids 401 spam from the background
    // isolate before the user has signed in).
    final token = await SecureDeviceService.getToken() ?? '';
    if (token.isEmpty) {
      return const CallContext(parentId: '', childId: '');
    }

    final parentId = await SecureDeviceService.getParentId() ?? '';
    var childId = await SecureDeviceService.getSelectedChildId() ?? '';

    if (childId.isEmpty) {
      try {
        final children = await _childRepository.fetchChildren();
        if (children.isNotEmpty) {
          final first = children.first;
          childId = first.id;
          await SecureDeviceService.saveSelectedChildId(first.id);
          await SecureDeviceService.saveSelectedChildDeviceKey(first.deviceKey);
        }
      } catch (_) {
        // Leave childId empty; caller handles the invalid context.
      }
    }

    return CallContext(parentId: parentId, childId: childId);
  }

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
