import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:vigil_parents_app/config/api_config.dart';

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

    // SMS polls run every 5s — keep their request/response out of the logs.
    if (!_isSilent(options.path)) {
      debugPrint("➡️ REQUEST[${options.method}] => ${options.path}");
      debugPrint("Headers: ${options.headers}");
      debugPrint("Body: ${options.data}");
    }

    handler.next(options);
  }

  /// Endpoints whose request/response bodies should not be logged.
  bool _isSilent(String path) => path.contains('/api/sms/');

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_isSilent(response.requestOptions.path)) {
      debugPrint("✅ RESPONSE[${response.statusCode}] => ${response.data}");
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    String message = "Something went wrong";

    if (err.response != null) {
      final data = err.response?.data;

      if (data is Map<String, dynamic>) {
        // ✅ Your backend uses "msg"
        if (data['msg'] != null) {
          message = data['msg'];
        } else if (data['message'] != null) {
          message = data['message'];
        }
      }

      debugPrint("❌ ERROR[${err.response?.statusCode}] => $message");
    } else {
      // Network / timeout
      if (err.type == DioExceptionType.connectionTimeout) {
        message = "Connection timeout";
      } else if (err.type == DioExceptionType.receiveTimeout) {
        message = "Server not responding";
      } else if (err.type == DioExceptionType.unknown) {
        message = "No internet connection";
      } else {
        message = err.message ?? "Unexpected error";
      }

      debugPrint("❌ NETWORK ERROR => $message");
    }

    // ✅ Throw clean message
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
