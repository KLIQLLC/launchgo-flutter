import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Interceptor that converts 4xx and 5xx responses into DioExceptions with clean error messages
/// This ensures that client errors (400-499) and server errors (500-599) are properly handled
class ErrorHandlingInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final statusCode = response.statusCode;

    // Check if response is a client error (4xx)
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      // Extract error message from response
      String errorMessage = _extractErrorMessage(response.data, statusCode);

      if (kDebugMode) {
        debugPrint('🚫 Client error detected: $statusCode - $errorMessage');
      }

      // Convert to DioException so it's handled as an error
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          message: errorMessage,
          error: errorMessage,
          type: DioExceptionType.badResponse,
          response: response,
        ),
      );
      return;
    }

    // Pass through successful responses (2xx, 3xx)
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Extract clean error messages from 5xx server errors
    final statusCode = err.response?.statusCode;

    if (statusCode != null && statusCode >= 500 && statusCode < 600) {
      String errorMessage = _extractErrorMessage(err.response?.data, statusCode);

      if (kDebugMode) {
        debugPrint('🔥 Server error detected: $statusCode - $errorMessage');
      }

      // Replace the error with a cleaner message
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          message: errorMessage,
          error: errorMessage,
          type: DioExceptionType.badResponse,
          response: err.response,
        ),
      );
      return;
    }

    // Pass through other errors (network errors, timeouts, etc.)
    super.onError(err, handler);
  }

  /// Extract error message from response data
  String _extractErrorMessage(dynamic data, int statusCode) {
    try {
      // Try to parse as JSON if it's a string
      dynamic parsedData = data;
      if (data is String) {
        try {
          parsedData = json.decode(data);
        } catch (_) {
          // If not JSON, use the string as is
          return data.isNotEmpty ? data : 'Request failed with status $statusCode';
        }
      }

      // Extract message from common error response formats
      if (parsedData is Map<String, dynamic>) {
        // Try different common error message fields
        final message = parsedData['message'] ??
                       parsedData['error'] ??
                       parsedData['errors'] ??
                       parsedData['detail'];

        if (message != null) {
          return message.toString();
        }
      }

      // Fallback to generic message
      return 'Request failed with status $statusCode';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to extract error message: $e');
      }
      return 'Request failed with status $statusCode';
    }
  }
}
