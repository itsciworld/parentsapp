import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/features/child/repo/child_repo.dart';
import 'package:vigil_parents_app/features/gallery/models/media_model.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

/// Identifiers needed to query media for a child.
class GalleryContext {
  final String parentId;
  final String childId;
  const GalleryContext({required this.parentId, required this.childId});

  bool get isValid => parentId.isNotEmpty && childId.isNotEmpty;
}

/// Talks to `/api/files/get_files` for the gallery / media-access feature.
class GalleryRepository {
  GalleryRepository({ApiClient? client, ChildRepository? childRepository})
    : _apiClient = client ?? ApiClient(),
      _childRepository = childRepository ?? ChildRepository();

  final ApiClient _apiClient;
  final ChildRepository _childRepository;

  /// Resolves the parent + child ids from storage. If no child is selected
  /// yet, it fetches the children list, picks the first, and remembers it
  /// (id + device key) so the background service can run headless.
  /// Mirrors [SmsRepository.resolveContext] so both stay in sync.
  Future<GalleryContext> resolveContext() async {
    // No session → don't hit the API (avoids 401 spam from the background
    // isolate before the user has signed in).
    final token = await SecureDeviceService.getToken() ?? '';
    if (token.isEmpty) {
      return const GalleryContext(parentId: '', childId: '');
    }

    final parentId = await SecureDeviceService.getParentId() ?? '';
    var childId = await SecureDeviceService.getSelectedChildId() ?? '';

    try {
      final children = await _childRepository.fetchChildren();
      if (children.isEmpty) {
        return GalleryContext(parentId: parentId, childId: '');
      }

      if (childId.isNotEmpty) {
        final selected = children.where((c) => c.id == childId).firstOrNull;
        if (selected != null) {
          await SecureDeviceService.saveSelectedChildDeviceKey(
            selected.deviceKey,
          );
        } else {
          final first = children.first;
          childId = first.id;
          await SecureDeviceService.saveSelectedChildId(first.id);
          await SecureDeviceService.saveSelectedChildDeviceKey(first.deviceKey);
        }
      } else {
        final first = children.first;
        childId = first.id;
        await SecureDeviceService.saveSelectedChildId(first.id);
        await SecureDeviceService.saveSelectedChildDeviceKey(first.deviceKey);
      }
    } catch (_) {
      // If the fetch fails, fall back to whatever is stored. The caller
      // handles an invalid context when childId ends up empty.
    }

    return GalleryContext(parentId: parentId, childId: childId);
  }

  /// Fetches a page of media for a child, optionally filtered by [filter].
  /// `x-device-key` is attached automatically by [ApiInterceptor].
  Future<MediaResponse> getFiles({
    required String childId,
    required String parentId,
    MediaFilter filter = MediaFilter.all,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final query = <String, dynamic>{
        'child_id': childId,
        'parent_id': parentId,
        'page': page,
        'limit': limit,
      };
      final fileType = filter.queryValue;
      if (fileType != null) query['file_type'] = fileType;

      final response = await _apiClient.get('/api/files/get_files', query: query);

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return MediaResponse.fromJson(data);
      }
      return MediaResponse.empty;
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}

final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepository();
});
