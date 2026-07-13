import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:vigil_parents_app/config/api_config.dart';
import 'package:vigil_parents_app/core/navigation/app_navigator.dart';
import 'package:vigil_parents_app/core/routing/routes.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';

class ApiInterceptor extends Interceptor {
  /// A bare Dio (no interceptors) used to refresh the token and replay the
  /// original request, so neither call recurses back through this interceptor.
  static final Dio _tokenDio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 65),
      receiveTimeout: const Duration(seconds: 65),
      sendTimeout: const Duration(seconds: 65),
    ),
  );

  /// Holds the in-flight refresh so a burst of parallel 401s triggers exactly
  /// one refresh call; they all await the same result.
  static Future<bool>? _refreshing;

  /// Guards against multiple stacked redirects to the login screen.
  static bool _loggingOut = false;

  /// Auth endpoints must never trigger a refresh/logout — a 401 there means
  /// bad credentials or an invalid refresh token, which should surface as a
  /// normal error message instead of wiping the session.
  bool _isAuthPath(String path) => path.contains('/api/auth/');

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['Content-Type'] = 'application/json';

    final token = await SecureDeviceService.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Attach the selected child's per-device key so child-scoped endpoints
    // (SMS, device-info, ...) receive it automatically. A caller-supplied
    // header wins, so explicit overrides still work.
    final deviceKey = await SecureDeviceService.getSelectedChildDeviceKey();
    if (deviceKey != null && deviceKey.isNotEmpty) {
      options.headers.putIfAbsent('x-device-key', () => deviceKey);
    }

    // SMS polls run every 5s — keep their request/response out of the logs.
    if (!_isSilent(options.path)) {
      debugPrint("➡️ REQUEST[${options.method}] => ${options.path}");
      debugPrint("Headers: ${options.headers}");
      debugPrint("Body: ${options.data}");
    } else {
      // Even for silent requests, log the device key to help debug auth issues
      debugPrint(
        "➡️ [Silent] ${options.method} ${options.path} | device-key: ${deviceKey ?? 'none'}",
      );
    }

    handler.next(options);
  }

  /// Endpoints whose request/response bodies should not be logged.
  /// Calendar events carry huge meeting descriptions and the AI endpoints
  /// return a large analysis payload / raw PDF bytes — logging any of them
  /// floods the console.
  bool _isSilent(String path) =>
      path.contains('/api/sms/') ||
      path.contains('/api/files/') ||
      path.contains('/api/events/') ||
      path.contains('/api/ai/');

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_isSilent(response.requestOptions.path)) {
      debugPrint("✅ RESPONSE[${response.statusCode}] => ${response.data}");
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    String message = "Something went wrong";

    if (err.response != null) {
      final statusCode = err.response?.statusCode;
      final data = err.response?.data;
      final path = err.requestOptions.path;

      if (data is Map<String, dynamic>) {
        if (data['msg'] != null) {
          message = data['msg'];
        } else if (data['message'] != null) {
          message = data['message'];
        }
      }

      debugPrint("❌ ERROR[$statusCode] => $message");

      // A missing `x-device-key` also comes back as 401, but it's a per-request
      // authorization gap (the selected child's key isn't stored yet), NOT an
      // expired session — it must never log the user out.
      final isDeviceKeyError = message.toLowerCase().contains('device key');

      // A 401 on a normal (non-auth) endpoint: try a silent token refresh and
      // replay the request before assuming the session is dead. We only bounce
      // to login when the refresh token itself is invalid/expired.
      if (statusCode == 401 && !_isAuthPath(path) && !isDeviceKeyError) {
        final refreshed = await _refreshToken();
        if (refreshed) {
          try {
            final replay = await _retry(err.requestOptions);
            return handler.resolve(replay);
          } catch (_) {
            // Refresh succeeded, so the session is valid — this remaining 401 is
            // request-specific (e.g. device key). Surface it, don't log out.
          }
        } else {
          // Refresh token missing/expired → the session is genuinely dead.
          await _forceLogout();
        }
      }
    } else {
      // Network / timeout
      if (err.type == DioExceptionType.connectionTimeout) {
        message = "Connection timeout. Please check your internet connection.";
      } else if (err.type == DioExceptionType.receiveTimeout || err.type == DioExceptionType.sendTimeout) {
        message = "Server not responding. Please try again later.";
      } else if (err.type == DioExceptionType.connectionError) {
        message = "No internet connection. Please check your network and try again.";
      } else if (err.type == DioExceptionType.unknown) {
        if (err.error != null && err.error.toString().contains('Failed host lookup')) {
          message = "No internet connection. Please check your network and try again.";
        } else {
          message = "Something went wrong with the network connection.";
        }
      } else {
        message = "Unexpected error occurred.";
      }

      debugPrint("❌ NETWORK ERROR => $message");
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: message,
        response: err.response,
      ),
    );
  }

  /// Exchanges the stored refresh token for a new access token. Concurrent
  /// callers share a single in-flight request. Returns true on success.
  Future<bool> _refreshToken() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await SecureDeviceService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      debugPrint("🔄 Refreshing access token…");
      final res = await _tokenDio.post(
        '/api/auth/refresh-token',
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final data = res.data;
      if (data is Map && data['token'] is String) {
        await SecureDeviceService.updateTokens(
          token: data['token'] as String,
          refreshToken: data['refreshToken'] as String?,
        );
        debugPrint("✅ Token refreshed");
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Token refresh failed => $e");
      return false;
    }
  }

  /// Replays the original request with the freshly refreshed token.
  Future<Response> _retry(RequestOptions options) async {
    final token = await SecureDeviceService.getToken();
    options.headers['Authorization'] = 'Bearer $token';
    return _tokenDio.fetch(options);
  }

  /// Clears the session and routes to login, guarded so a burst of failed
  /// requests can't stack multiple redirects.
  Future<void> _forceLogout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    await SecureDeviceService.clearAuthData();
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutesName.loginView,
      (_) => false,
    );
    _loggingOut = false;
  }
}

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 65),
        receiveTimeout: const Duration(seconds: 65),
        sendTimeout: const Duration(seconds: 65),
      ),
    );

    _dio.interceptors.add(ApiInterceptor());
  }

  // ✅ GET
  Future<Response> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: query,
        options: headers == null ? null : Options(headers: headers),
      );
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    }
  }

  // ✅ GET (raw bytes — e.g. PDF/file downloads)
  Future<Response<List<int>>> getBytes(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      return await _dio.get<List<int>>(
        path,
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes),
      );
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    }
  }

  // ✅ POST
  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    }
  }

  // ✅ PUT
  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    }
  }

  // ✅ DELETE
  Future<Response> delete(String path, {dynamic data}) async {
    try {
      return await _dio.delete(path, data: data);
    } on DioException catch (e) {
      throw Exception(e.error.toString());
    }
  }
}
