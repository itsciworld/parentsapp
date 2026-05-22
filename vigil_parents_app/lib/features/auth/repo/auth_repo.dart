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

  // مشترك helper to read the "msg" field from a plain status response
  String _readMessage(Response response, String fallback) {
    final data = response.data;
    if (data is Map && data['msg'] != null) {
      return data['msg'].toString();
    }
    return fallback;
  }

  // FORGOT PASSWORD → STEP 1: request a reset code by email
  Future<String> requestPasswordReset(String email) async {
    try {
      final response = await _apiClient.post(
        "/api/auth/request-password-reset",
        data: {"email": email},
      );

      return _readMessage(response, "Reset code sent to your email");
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // FORGOT PASSWORD → STEP 2: verify the OTP sent to the email
  Future<String> verifyOtp(String email, String otp) async {
    try {
      final response = await _apiClient.post(
        "/api/auth/verify-otp",
        data: {"email": email, "otp": otp},
      );

      return _readMessage(response, "OTP verified successfully");
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // FORGOT PASSWORD → STEP 3: set a new password using the verified OTP
  Future<String> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      final response = await _apiClient.post(
        "/api/auth/reset-password",
        data: {"email": email, "otp": otp, "newPassword": newPassword},
      );

      return _readMessage(response, "Password has been reset successfully");
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
