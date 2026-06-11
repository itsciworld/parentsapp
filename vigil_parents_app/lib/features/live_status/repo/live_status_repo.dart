import 'package:dio/dio.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/features/child/repo/child_repo.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

import '../models/live_status_model.dart';

/// Identifier needed to query the live status for a child.
class LiveStatusContext {
  final String childId;
  const LiveStatusContext({required this.childId});

  bool get isValid => childId.isNotEmpty;
}

class LiveStatusRepository {
  LiveStatusRepository({ApiClient? client, ChildRepository? childRepository})
    : _apiClient = client ?? ApiClient(),
      _childRepository = childRepository ?? ChildRepository();

  final ApiClient _apiClient;
  final ChildRepository _childRepository;

  /// Resolves the child id from storage. If no child is selected yet, it
  /// fetches the children list, picks the first, and remembers it (id +
  /// device key) so the background service can run headless.
  Future<LiveStatusContext> resolveContext() async {
    // No session → don't hit the API (avoids 401 spam from the background
    // isolate before the user has signed in).
    final token = await SecureDeviceService.getToken() ?? '';
    if (token.isEmpty) {
      return const LiveStatusContext(childId: '');
    }

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

    return LiveStatusContext(childId: childId);
  }

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
