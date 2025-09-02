import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../services/auth_service.dart';
import '../../services/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  final AuthService _authService;
  
  AuthInterceptor({
    required AuthService authService,
    required Dio dio,
  }) : _authService = authService;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip token expiration check for auth endpoints
    final isAuthEndpoint = options.path.contains('/auth/') || 
                          options.path.contains('/login') ||
                          options.path.contains('/signin');
    
    if (!isAuthEndpoint) {
      // Only check token expiration for non-auth endpoints
      final token = _authService.accessToken;
      if (token != null) {
        // We have a token, check if it's expired
        final isExpired = await SecureStorageService.isTokenExpired();
        if (isExpired) {
          debugPrint('⏰ Token expired. Signing out and redirecting to login...');
          
          // Sign out to clear state and trigger navigation
          await _authService.signOut();
          
          // Reject the request with auth error
          handler.reject(
            DioException(
              requestOptions: options,
              error: 'Token expired. Please sign in again.',
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 401,
                statusMessage: 'Unauthorized',
              ),
            ),
          );
          return;
        }
      }
    }
    
    // Add auth token to all requests
    final token = _authService.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    // Add common headers
    options.headers['Content-Type'] = 'application/json';
    options.headers['Accept'] = 'application/json';
    
    // Log request in debug mode
    if (kDebugMode) {
      debugPrint('🚀 REQUEST[${options.method}] => PATH: ${options.path}');
      debugPrint('Headers: ${options.headers}');
      if (options.data != null) {
        debugPrint('Body: ${options.data}');
      }
    }
    
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Log response in debug mode
    if (kDebugMode) {
      debugPrint('✅ RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
    }
    
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (kDebugMode) {
      debugPrint('❌ ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}');
      debugPrint('Error: ${err.message}');
      if (err.response?.data != null) {
        debugPrint('Error Data: ${err.response?.data}');
      }
    }
    
    // Handle different error codes
    switch (err.response?.statusCode) {
      case 401:
        // Token expired or invalid
        await _handleUnauthorized(err, handler);
        break;
      case 403:
        // Forbidden - user doesn't have permission
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: 'Access forbidden. You may not have permission to access this resource.',
            type: DioExceptionType.badResponse,
            response: err.response,
          ),
        );
        break;
      case 404:
        // Not found
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: 'Resource not found',
            type: DioExceptionType.badResponse,
            response: err.response,
          ),
        );
        break;
      case 500:
      case 502:
      case 503:
        // Server error - could retry
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: 'Server error. Please try again later.',
            type: DioExceptionType.badResponse,
            response: err.response,
          ),
        );
        break;
      default:
        // Pass through other errors
        handler.reject(err);
    }
  }
  
  Future<void> _handleUnauthorized(DioException err, ErrorInterceptorHandler handler) async {
    // Check if token is expired or we got a 401
    final isExpired = await SecureStorageService.isTokenExpired();
    
    if (isExpired || err.response?.statusCode == 401) {
      debugPrint('🔐 Token expired or unauthorized. Signing out and redirecting to login...');
      
      // Sign out will clear tokens and notify listeners
      // The router is listening to authService (refreshListenable: authService)
      // and will automatically redirect to /login
      await _authService.signOut();
      
      // Reject with a specific error message
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: 'Session expired. Please sign in again.',
          type: DioExceptionType.badResponse,
          response: err.response,
        ),
      );
    } else {
      // Other 401 errors
      handler.reject(err);
    }
  }
}