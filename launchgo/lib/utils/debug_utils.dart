import 'package:flutter/foundation.dart';
import '../services/secure_storage_service.dart';
import '../services/auth_service.dart';

/// Debug utilities for testing various app scenarios
/// Only available in debug mode
class DebugUtils {
  /// Test token expiration by manipulating the stored expiry time
  static Future<void> expireTokenNow() async {
    if (!kDebugMode) return;
    
    debugPrint('🔧 DEBUG: Expiring token now for testing...');
    
    // Set token expiry to past time
    final expiredTime = DateTime.now().subtract(const Duration(hours: 1));
    await SecureStorageService.saveTokenExpiry(expiredTime);
    
    debugPrint('✅ Token expiry set to: $expiredTime');
    debugPrint('📝 Next API call should trigger 401 handling');
  }
  
  /// Test token expiration in X seconds
  static Future<void> expireTokenIn(Duration duration) async {
    if (!kDebugMode) return;
    
    debugPrint('🔧 DEBUG: Setting token to expire in ${duration.inSeconds} seconds...');
    
    // Set token expiry to future time
    final expiryTime = DateTime.now().add(duration);
    await SecureStorageService.saveTokenExpiry(expiryTime);
    
    debugPrint('✅ Token will expire at: $expiryTime');
  }
  
  /// Clear the stored token to simulate unauthorized state
  static Future<void> clearToken() async {
    if (!kDebugMode) return;
    
    debugPrint('🔧 DEBUG: Clearing access token...');
    await SecureStorageService.clearAllAuthData();
    debugPrint('✅ Token cleared. Next API call should fail with 401');
  }
  
  /// Corrupt the token to simulate invalid token
  static Future<void> corruptToken() async {
    if (!kDebugMode) return;
    
    debugPrint('🔧 DEBUG: Corrupting access token...');
    await SecureStorageService.saveAccessToken('invalid_corrupted_token_12345');
    debugPrint('✅ Token corrupted. Next API call should fail with 401');
  }
  
  /// Check current token status
  static Future<void> checkTokenStatus() async {
    if (!kDebugMode) return;
    
    debugPrint('🔍 DEBUG: Checking token status...');
    
    final token = await SecureStorageService.getAccessToken();
    if (token == null) {
      debugPrint('❌ No token stored');
      return;
    }
    
    debugPrint('✅ Token exists: ${token.substring(0, 20)}...');
    
    final isExpired = await SecureStorageService.isTokenExpired();
    debugPrint('⏰ Token expired: $isExpired');
    
    final expiry = await SecureStorageService.getTokenExpiry();
    if (expiry != null) {
      final remaining = expiry.difference(DateTime.now());
      if (remaining.isNegative) {
        debugPrint('⏰ Token expired ${remaining.abs().inMinutes} minutes ago');
      } else {
        debugPrint('⏰ Token expires in ${remaining.inMinutes} minutes');
      }
    }
  }
  
  /// Simulate a 401 response from the server
  static Future<void> triggerUnauthorized(AuthService authService) async {
    if (!kDebugMode) return;
    
    debugPrint('🔧 DEBUG: Triggering unauthorized by signing out...');
    await authService.signOut();
    debugPrint('✅ User signed out. Should redirect to login');
  }
}