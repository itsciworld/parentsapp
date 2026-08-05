import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/core/services/child_context/child_context_resolver.dart';
import 'package:vigil_parents_app/features/gallery/models/media_model.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

/// Identifiers needed to query media for a child.
typedef GalleryContext = ChildContext;

/// Talks to `/api/files/get_files` for the gallery / media-access feature.
class GalleryRepository {
  GalleryRepository({ApiClient? client}) : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  /// See [ChildContextResolver.resolve] — shared across features and
  /// cached, so polling callers no longer re-fetch the children list.
  Future<GalleryContext> resolveContext() => ChildContextResolver.resolve();

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

      final response = await _apiClient.get(
        '/api/files/get_files',
        query: query,
      );

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
