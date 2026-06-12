import 'package:dio/dio.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

import '../models/location_model.dart';

class LocationRepository {
  LocationRepository({ApiClient? client}) : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  /// GET /api/locations/get_locations — every recorded location point for the
  /// child, newest first. `x-device-key` is attached automatically by
  /// [ApiInterceptor] from the selected child's stored device key.
  Future<List<ChildLocation>> getLocations({
    required String childId,
    int page = 1,
    int limit = 20,
  }) async {
    final parentId = await SecureDeviceService.getParentId() ?? '';

    try {
      final response = await _apiClient.get(
        '/api/locations/get_locations',
        query: {
          'child_id': childId,
          'parent_id': parentId,
          'page': page,
          'limit': limit,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final locations = LocationsResponse.fromJson(data).locations;
        // The Mongo `_id` encodes creation time, so sorting it descending puts
        // the most recent fix first regardless of the array order returned.
        locations.sort((a, b) => b.id.compareTo(a.id));
        return locations;
      }
      return const [];
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
