import 'package:dio/dio.dart';
import 'package:vigil_parents_app/features/profile/models/profile_model.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

class ProfileRepository {
  ProfileRepository({ApiClient? client}) : _apiClient = client ?? ApiClient();

  final ApiClient _apiClient;

  Future<ProfileModel> getProfile() async {
    try {
      final response = await _apiClient.get('/api/auth/me');
      final data = response.data;

      if (data is Map<String, dynamic> && data['user'] is Map) {
        return ProfileModel.fromJson(
          Map<String, dynamic>.from(data['user'] as Map),
        );
      }

      // Some backends return the user object directly.
      if (data is Map<String, dynamic>) {
        return ProfileModel.fromJson(data);
      }

      throw Exception('Invalid profile response');
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
