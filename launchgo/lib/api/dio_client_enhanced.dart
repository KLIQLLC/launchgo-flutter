import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/environment.dart';
import '../services/auth_service.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_handling_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

class DioClientEnhanced {
  late final Dio _dio;
  final AuthService _authService;
  
  DioClientEnhanced({required AuthService authService}) : _authService = authService {
    _dio = _createDio();
  }
  
  Dio get dio => _dio;
  
  Dio _createDio() {
    final dio = Dio();
    
    // Configure base options
    dio.options = BaseOptions(
      baseUrl: EnvironmentConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null && status < 500,
    );
    
    // Add interceptors in order
    // 1. Auth interceptor (adds token, handles 401)
    dio.interceptors.add(AuthInterceptor(
      authService: _authService,
      dio: dio,
    ));

    // 2. Error handling interceptor (converts 4xx and 5xx responses to exceptions with clean messages)
    dio.interceptors.add(ErrorHandlingInterceptor());

    // 3. Logging interceptor (for debugging)
    if (kDebugMode) {
      dio.interceptors.add(LoggingInterceptor());
    }

    // 4. Retry interceptor (optional - for network issues)
    dio.interceptors.add(RetryInterceptor(dio: dio));
    
    return dio;
  }
}

/// Retry interceptor for handling transient network errors
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration retryDelay;
  
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
  });
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Only retry on network errors, not on 4xx errors
    final shouldRetry = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode != null && err.response!.statusCode! >= 500);
    
    if (!shouldRetry) {
      return handler.next(err);
    }
    
    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;
    
    if (retryCount >= maxRetries) {
      return handler.next(err);
    }
    
    // Exponential backoff
    final delay = retryDelay * (retryCount + 1);
    
    if (kDebugMode) {
      debugPrint('🔄 Retrying request (${retryCount + 1}/$maxRetries) after ${delay.inSeconds}s...');
    }
    
    await Future.delayed(delay);
    
    try {
      err.requestOptions.extra['retryCount'] = retryCount + 1;
      final response = await dio.fetch(err.requestOptions);
      handler.resolve(response);
    } catch (e) {
      handler.next(err);
    }
  }
}