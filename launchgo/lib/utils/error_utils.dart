import 'package:dio/dio.dart';

/// Utility class for handling and formatting error messages
class ErrorUtils {
  /// Extract a user-friendly error message from any exception
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      // For DioException, extract the message field first
      if (error.message != null && error.message!.isNotEmpty) {
        return error.message!;
      }

      // Fallback to error field if message is not available
      if (error.error != null) {
        return error.error.toString();
      }

      // Fallback to generic message based on type
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return 'Connection timeout. Please check your internet connection.';
        case DioExceptionType.sendTimeout:
          return 'Request timeout. Please try again.';
        case DioExceptionType.receiveTimeout:
          return 'Response timeout. Please try again.';
        case DioExceptionType.connectionError:
          return 'Connection error. Please check your internet connection.';
        case DioExceptionType.badResponse:
          return 'Request failed. Please try again.';
        case DioExceptionType.cancel:
          return 'Request was cancelled.';
        default:
          return 'An unexpected error occurred.';
      }
    }

    // For other exceptions, return their string representation
    return error.toString();
  }
}
