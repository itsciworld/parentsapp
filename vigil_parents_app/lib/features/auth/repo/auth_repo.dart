import 'package:dio/dio.dart';

import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';
import 'package:vigil_parents_app/network/api_intercptor.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  // مشتر function to handle response
  Future<String> _handleAuth(Response response, String email) async {
    final data = response.data;

    final String? token = data['token'];
    final String? refreshToken = data['refreshToken'];
    final String? parentId = data['userId'];
    final String? parentName = data['userName'];

    if (token != null) {
      await SecureDeviceService.saveAuthData(
        token: token,
        email: email,
        refreshToken: refreshToken,
        parentId: parentId,
        parentName: parentName,
      );

      return data['msg'] ?? "Success";
    } else {
      throw Exception("Invalid server response");
    }
  }

  // The single sentence the login screen shows when the email isn't registered,
  // whichever wording the backend happens to use for it.
  static const String _accountNotFoundMessage =
      'No Account found with this email address. Please check and try again';

  static final List<RegExp> _accountNotFoundPatterns = [
    RegExp(r'(user|account|email|e-?mail)\s+not\s+found', caseSensitive: false),
    RegExp(
      r"(user|account|email|e-?mail)\s+(does\s*n[o']?t|doesn't)\s+exist",
      caseSensitive: false,
    ),
    RegExp(r'no\s+(such\s+)?(user|account)', caseSensitive: false),
    RegExp(r'not\s+registered', caseSensitive: false),
    RegExp(r'unregistered\s+(user|account|email)', caseSensitive: false),
  ];

  /// Normalises a login failure into the copy the screen expects. Anything that
  /// isn't recognisably an "unknown email" stays as the server sent it, so a
  /// wrong password or an outage is never mislabelled as a missing account.
  String _mapLoginError(String? raw, int? statusCode) {
    final message = (raw ?? '').replaceAll('Exception: ', '').trim();

    final isUnknownAccount =
        statusCode == 404 ||
        _accountNotFoundPatterns.any((p) => p.hasMatch(message));

    if (isUnknownAccount) return _accountNotFoundMessage;

    return message.isEmpty ? 'Login failed. Please try again.' : message;
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
      throw Exception(
        _mapLoginError(e.error?.toString(), e.response?.statusCode),
      );
    } catch (e) {
      throw Exception(_mapLoginError(e.toString(), null));
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

  // LOGOUT — notify backend, then always clear local auth data
  Future<String> logout() async {
    try {
      final response = await _apiClient.post("/api/auth/logout");
      return _readMessage(response, "Logged out successfully");
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    } finally {
      // Local session must be cleared even if the network call fails.
      await SecureDeviceService.clearAuthData();
    }
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
