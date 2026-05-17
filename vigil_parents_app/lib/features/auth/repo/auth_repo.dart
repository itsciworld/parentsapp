import 'package:dio/dio.dart';

import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  // مشتر function to handle response
  Future<String> _handleAuth(Response response, String email) async {
    final data = response.data;

    final String? token = data['token'];
    final String? parentId = data['userId'];
    final String? parentName = data['userName'];

    if (token != null) {
      await SecureDeviceService.saveAuthData(
        token: token,
        email: email,
        parentId: parentId,
        parentName: parentName,
      );

      return data['msg'] ?? "Success";
    } else {
      throw Exception("Invalid server response");
    }
  }

  // LOGIN
  Future<String> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        "/api/auth/login",
        data: {"email": email, "password": password},
      );

      return await _handleAuth(response, email);
    } on DioException catch (e) {
      throw Exception(e.error.toString()); // ✅ clean message
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // REGISTER
  Future<String> register(String name, String email, String password) async {
    try {
      final response = await _apiClient.post(
        "/api/auth/register",
        data: {"name": name, "email": email, "password": password},
      );

      return await _handleAuth(response, email);
    } on DioException catch (e) {
      throw Exception(e.error.toString()); // ✅ clean message
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
