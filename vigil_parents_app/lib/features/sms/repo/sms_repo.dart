import 'package:dio/dio.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/features/child/repo/child_repo.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

import '../models/sms_model.dart';

/// Identifiers needed to query SMS for a child.
class SmsContext {
  final String parentId;
  final String childId;
  const SmsContext({required this.parentId, required this.childId});

  bool get isValid => parentId.isNotEmpty && childId.isNotEmpty;
}

class SmsRepository {
  SmsRepository({ApiClient? client, ChildRepository? childRepository})
    : _apiClient = client ?? ApiClient(),
      _childRepository = childRepository ?? ChildRepository();

  final ApiClient _apiClient;
  final ChildRepository _childRepository;

  /// Static fallback device key — sent in the `x-device-key` header until a
  /// real per-device key is provisioned.
  static const String fallbackDeviceKey = 'vigil_device_key_2026_def456uvw';

  /// Resolves the parent + child ids from storage. If no child is selected
  /// yet, it fetches the children list, picks the first, and remembers it so
  /// the background service can run headless.
  Future<SmsContext> resolveContext() async {
    final parentId = await SecureDeviceService.getParentId() ?? '';
    var childId = await SecureDeviceService.getSelectedChildId() ?? '';

    if (childId.isEmpty) {
      try {
        final children = await _childRepository.fetchChildren();
        if (children.isNotEmpty) {
          childId = children.first.id;
          await SecureDeviceService.saveSelectedChildId(childId);
        }
      } catch (_) {
        // Leave childId empty; caller handles the invalid context.
      }
    }

    return SmsContext(parentId: parentId, childId: childId);
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
        headers: {'x-device-key': fallbackDeviceKey},
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
