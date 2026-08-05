import 'package:dio/dio.dart';

import 'package:vigil_parents_app/core/services/child_context/child_context_resolver.dart';
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

  // REGISTER → STEP 1: email the user a one-time code. Nothing is created
  // server-side yet; the account only exists once step 2 succeeds.
  Future<String> sendRegisterOtp(String name, String email) async {
    try {
      final response = await _apiClient.post(
        "/api/auth/send-register-otp",
        data: {"name": name, "email": email},
      );

      return _readMessage(response, "Verification code sent to your email");
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // REGISTER → STEP 2: create the account with the emailed code. A 201 comes
  // back already authenticated (token + refreshToken), so the caller can go
  // straight to the dashboard without a separate login round-trip.
  Future<String> registerWithOtp({
    required String name,
    required String email,
    required String password,
    required String otp,
  }) async {
    try {
      final response = await _apiClient.post(
        "/api/auth/register-website",
        data: {"name": name, "email": email, "password": password, "otp": otp},
      );

      final data = response.data;
      final String? token = data is Map ? data['token'] as String? : null;

      if (token == null || token.isEmpty) {
        throw Exception("Invalid server response");
      }

      await SecureDeviceService.saveAuthData(
        token: token,
        email: email,
        refreshToken: data['refreshToken'] as String?,
        parentId: data['userId'] as String?,
        // The register response carries no userName — fall back to what the
        // user just typed so the dashboard has a name to greet them with.
        parentName: (data['userName'] as String?) ?? name,
        deviceKey: data['deviceKey'] as String?,
      );

      return _readMessage(response, "Account created successfully");
    } on DioException catch (e) {
      // Matched on the message alone, not the status code: this endpoint also
      // returns 400 for a duplicate email or a rejected password, and those
      // must keep the server's wording instead of becoming "Invalid OTP".
      throw Exception(
        _mapOtpError(
          e.error?.toString(),
          fallback: 'Could not create your account. Please try again.',
        ),
      );
    } catch (e) {
      throw Exception(
        _mapOtpError(
          e.toString(),
          fallback: 'Could not create your account. Please try again.',
        ),
      );
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
      // Drop the cached parent/child ids too, so the next sign-in on this
      // device can't inherit the previous account's selected child.
      ChildContextResolver.invalidate();
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

  // The single sentence every OTP failure shows. A wrong code, a code that was
  // already used and one that has expired are all the same thing to the user,
  // and telling them apart only helps someone guessing codes.
  static const String _invalidOtpMessage = 'Invalid OTP. Please try again.';

  static final List<RegExp> _invalidOtpPatterns = [
    RegExp(r'(otp|code|token)', caseSensitive: false),
    RegExp(r'expired', caseSensitive: false),
  ];

  /// Normalises an OTP failure. Anything that isn't recognisably about the code
  /// itself (an outage, a timeout, a rejected new password) keeps the server's
  /// wording, so those are never mislabelled as a bad OTP.
  ///
  /// [statusCode] is only passed on the verify step, where a 4xx can *only*
  /// mean the code was rejected. The reset step matches on the message alone,
  /// because there a 400 may equally be about the new password.
  String _mapOtpError(
    String? raw, {
    int? statusCode,
    required String fallback,
  }) {
    final message = (raw ?? '').replaceAll('Exception: ', '').trim();

    final isOtpRejection =
        statusCode == 400 ||
        statusCode == 401 ||
        statusCode == 410 ||
        _invalidOtpPatterns.any((p) => p.hasMatch(message));

    if (isOtpRejection) return _invalidOtpMessage;

    return message.isEmpty ? fallback : message;
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
      throw Exception(
        _mapOtpError(
          e.error?.toString(),
          statusCode: e.response?.statusCode,
          fallback: _invalidOtpMessage,
        ),
      );
    } catch (e) {
      throw Exception(_mapOtpError(e.toString(), fallback: _invalidOtpMessage));
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
      // A reused or expired OTP surfaces here too, when the user takes the
      // long way round from the verify step to this one.
      throw Exception(
        _mapOtpError(
          e.error?.toString(),
          fallback: 'Could not reset your password. Please try again.',
        ),
      );
    } catch (e) {
      throw Exception(
        _mapOtpError(
          e.toString(),
          fallback: 'Could not reset your password. Please try again.',
        ),
      );
    }
  }
}
