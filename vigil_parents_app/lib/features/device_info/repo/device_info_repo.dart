import 'package:dio/dio.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

import '../models/device_info_model.dart';

class DeviceInfoRepository {
  DeviceInfoRepository({ApiClient? client})
    : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  /// GET /api/children/{childId}/device-info
  ///
  /// The bearer token is attached automatically by [ApiInterceptor].
  Future<DeviceInfoResponse> fetchDeviceInfo(String childId) async {
    try {
      final response = await _apiClient.get(
        '/api/children/$childId/device-info',
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return DeviceInfoResponse.fromJson(data);
      }
      throw Exception('Invalid device-info response');
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
