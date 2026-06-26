import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:vigil_parents_app/config/api_config.dart';
import 'package:vigil_parents_app/core/navigation/app_navigator.dart';
import 'package:vigil_parents_app/core/routing/routes.dart';
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';

class ApiInterceptor extends Interceptor {
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
  bool _isSilent(String path) =>
      path.contains('/api/sms/') || path.contains('/api/files/');

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

      if (data is Map<String, dynamic>) {
        if (data['msg'] != null) {
          message = data['msg'];
        } else if (data['message'] != null) {
          message = data['message'];
        }
      }

      debugPrint("❌ ERROR[$statusCode] => $message");

      if (statusCode == 401) {
        await SecureDeviceService.clearAuthData();
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutesName.loginView,
          (_) => false,
        );
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
