import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class DioClient {
  static Dio createDio() {
    final dio = Dio();
    
    // Configure Dio options
    dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    // Add logging interceptor for debugging
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ));
    }

    // Add error handling interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) {
          // Handle common errors
          switch (e.type) {
            case DioExceptionType.connectionTimeout:
            case DioExceptionType.sendTimeout:
            case DioExceptionType.receiveTimeout:
              debugPrint('Timeout error: ${e.message}');
              break;
            case DioExceptionType.badResponse:
              debugPrint('Bad response: ${e.response?.statusCode} - ${e.response?.data}');
              break;
            case DioExceptionType.cancel:
              debugPrint('Request cancelled');
              break;
            default:
              debugPrint('Dio error: ${e.message}');
          }
          handler.next(e);
        },
      ),
    );

    return dio;
  }
}