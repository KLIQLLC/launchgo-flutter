import 'package:flutter/material.dart';

/// Handles chat-related errors and provides user-friendly messages
class ChatErrorHandler {
  /// Convert technical errors to user-friendly messages
  static String getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('token')) {
      return 'Authentication issue. Please try logging in again.';
    }
    
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network connection problem. Please check your internet connection.';
    }
    
    if (errorString.contains('permission') || errorString.contains('unauthorized')) {
      return 'You don\'t have permission to access this chat.';
    }
    
    if (errorString.contains('student')) {
      return 'No students available for chat.';
    }
    
    if (errorString.contains('channel')) {
      return 'Unable to load chat conversation. Please try again.';
    }
    
    // Default message for unknown errors
    return 'Something went wrong. Please try again.';
  }

  /// Log error with context
  static void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('❌ [CHAT ERROR] $context: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Show error snackbar
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    final message = getUserFriendlyMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Check if error is recoverable
  static bool isRecoverableError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Network errors are usually recoverable
    if (errorString.contains('network') || errorString.contains('connection')) {
      return true;
    }
    
    // Channel errors are usually recoverable
    if (errorString.contains('channel')) {
      return true;
    }
    
    // Token errors might be recoverable with re-auth
    if (errorString.contains('token')) {
      return true;
    }
    
    return false;
  }

  /// Get retry strategy based on error type
  static Duration getRetryDelay(dynamic error, int attemptNumber) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network')) {
      // Exponential backoff for network errors
      return Duration(seconds: 2 * attemptNumber);
    }
    
    if (errorString.contains('token')) {
      // Immediate retry for token errors
      return const Duration(milliseconds: 500);
    }
    
    // Default retry delay
    return Duration(seconds: 1 * attemptNumber);
  }
}