import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:launchgo/config/environment.dart';

/// Service for secure storage of authentication tokens with environment-specific keys
class SecureStorageService {
  // iOS: when the phone is locked, Keychain items with the default accessibility
  // (whenUnlocked) can be temporarily unreadable. This can happen when CallKit wakes
  // the app from the lock screen, causing auth init to think the user is logged out.
  //
  // Using `first_unlock_this_device` keeps tokens readable after the device has been
  // unlocked at least once since boot (and prevents iCloud Keychain sync).
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static bool _isLikelyIOSProtectedDataError(Object e) {
    if (e is PlatformException) {
      final msg = '${e.code} ${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();
      // Common iOS Keychain/Protected Data errors while device is locked.
      return msg.contains('-25308') || // errSecInteractionNotAllowed
          msg.contains('interactionnotallowed') ||
          msg.contains('protected') ||
          msg.contains('unlocked');
    }
    return false;
  }

  static Future<String?> _readSafe(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      if (_isLikelyIOSProtectedDataError(e)) {
        // Treat as "temporarily unavailable" rather than logged out.
        return null;
      }
      rethrow;
    }
  }

  static Future<void> _writeSafe(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      if (_isLikelyIOSProtectedDataError(e)) {
        // If protected data is unavailable we cannot persist right now.
        // Let caller retry later; don't crash the app.
        return;
      }
      rethrow;
    }
  }

  static Future<void> _deleteSafe(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      if (_isLikelyIOSProtectedDataError(e)) {
        return;
      }
      rethrow;
    }
  }
  
  /// Get environment-specific storage key
  static String _getEnvironmentKey(String baseKey) {
    final env = EnvironmentConfig.isStage ? 'stage' : 'prod';
    return '${baseKey}_$env';
  }
  
  // Storage keys (environment-specific)
  static String get _accessTokenKey => _getEnvironmentKey('access_token');
  static String get _refreshTokenKey => _getEnvironmentKey('refresh_token');
  static String get _tokenExpiryKey => _getEnvironmentKey('token_expiry');
  
  /// Save access token
  static Future<void> saveAccessToken(String token) async {
    await _writeSafe(_accessTokenKey, token);
  }
  
  /// Get access token
  static Future<String?> getAccessToken() async {
    return await _readSafe(_accessTokenKey);
  }
  
  /// Delete access token
  static Future<void> deleteAccessToken() async {
    await _deleteSafe(_accessTokenKey);
  }
  
  /// Save refresh token
  static Future<void> saveRefreshToken(String token) async {
    await _writeSafe(_refreshTokenKey, token);
  }
  
  /// Get refresh token
  static Future<String?> getRefreshToken() async {
    return await _readSafe(_refreshTokenKey);
  }
  
  /// Delete refresh token
  static Future<void> deleteRefreshToken() async {
    await _deleteSafe(_refreshTokenKey);
  }
  
  /// Save token expiry
  static Future<void> saveTokenExpiry(DateTime expiry) async {
    await _writeSafe(_tokenExpiryKey, expiry.toIso8601String());
  }
  
  /// Get token expiry
  static Future<DateTime?> getTokenExpiry() async {
    final expiryString = await _readSafe(_tokenExpiryKey);
    if (expiryString != null) {
      return DateTime.tryParse(expiryString);
    }
    return null;
  }
  
  /// Delete token expiry
  static Future<void> deleteTokenExpiry() async {
    await _deleteSafe(_tokenExpiryKey);
  }
  
  /// Clear all auth data for current environment
  static Future<void> clearAllAuthData() async {
    await _deleteSafe(_accessTokenKey);
    await _deleteSafe(_refreshTokenKey);
    await _deleteSafe(_tokenExpiryKey);
  }
  
  /// Clear all auth data for ALL environments
  static Future<void> clearAllEnvironmentAuthData() async {
    // Clear stage tokens
    await _deleteSafe('access_token_stage');
    await _deleteSafe('refresh_token_stage');
    await _deleteSafe('token_expiry_stage');
    
    // Clear prod tokens
    await _deleteSafe('access_token_prod');
    await _deleteSafe('refresh_token_prod');
    await _deleteSafe('token_expiry_prod');
    
    // Clear legacy non-environment-specific tokens
    await _deleteSafe('access_token');
    await _deleteSafe('refresh_token');
    await _deleteSafe('token_expiry');
  }
  
  /// Check if token is expired
  static Future<bool> isTokenExpired() async {
    // First try to get stored expiry
    final expiry = await getTokenExpiry();
    if (expiry != null) {
      return DateTime.now().isAfter(expiry);
    }
    
    // If no expiry stored, try to decode from JWT token
    final token = await getAccessToken();
    if (token != null) {
      try {
        return JwtDecoder.isExpired(token);
      } catch (e) {
        // If JWT decode fails, assume token is valid
        return false;
      }
    }
    
    // No token means not authenticated, not expired
    return false;
  }
  
  /// Migrate old tokens to environment-specific storage
  static Future<void> migrateOldTokens() async {
    // Check for legacy tokens without environment suffix
    final oldAccessToken = await _readSafe('access_token');
    final oldRefreshToken = await _readSafe('refresh_token');
    final oldTokenExpiry = await _readSafe('token_expiry');
    
    if (oldAccessToken != null || oldRefreshToken != null) {
      // Migrate to current environment
      if (oldAccessToken != null) {
        await saveAccessToken(oldAccessToken);
      }
      if (oldRefreshToken != null) {
        await saveRefreshToken(oldRefreshToken);
      }
      if (oldTokenExpiry != null) {
        await _writeSafe(_tokenExpiryKey, oldTokenExpiry);
      }
      
      // Clear old tokens
      await _deleteSafe('access_token');
      await _deleteSafe('refresh_token');
      await _deleteSafe('token_expiry');
    }
  }
  
  /// Clear old environment tokens
  static Future<void> clearOldEnvironmentTokens() async {
    await clearAllEnvironmentAuthData();
  }
}