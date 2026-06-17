import 'package:dio/dio.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

import '../models/location_model.dart';

class LocationRepository {
  LocationRepository({ApiClient? client}) : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  /// GET /api/locations/latest/{childId} — the child's single most recent fix,
  /// updated in place server-side as new locations arrive. Returns `null` when
  /// nothing has been recorded yet. `x-device-key` is attached automatically by
  /// [ApiInterceptor] from the selected child's stored device key.
  Future<ChildLocation?> getLatestLocation({required String childId}) async {
    try {
      final response = await _apiClient.get('/api/locations/latest/$childId');

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return LatestLocationResponse.fromJson(data).location;
      }
      return null;
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// GET /api/locations/history/{childId}?hours=N — every fix recorded within
  /// the last [hours] hours (server caps the window at 48h), newest first.
  /// `x-device-key` is attached automatically by [ApiInterceptor].
  Future<LocationHistoryResponse> getLocationHistory({
    required String childId,
    int hours = 48,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/locations/history/$childId',
        query: {'hours': hours},
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return LocationHistoryResponse.fromJson(data);
      }
      return const LocationHistoryResponse(
        status: 200,
        windowHours: 0,
        since: null,
        total: 0,
        locations: [],
      );
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
