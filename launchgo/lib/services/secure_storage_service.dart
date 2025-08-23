import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:launchgo/config/environment.dart';

/// Service for secure storage of authentication tokens with environment-specific keys
class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  
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
    await _storage.write(key: _accessTokenKey, value: token);
  }
  
  /// Get access token
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }
  
  /// Delete access token
  static Future<void> deleteAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
  }
  
  /// Save refresh token
  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }
  
  /// Get refresh token
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }
  
  /// Delete refresh token
  static Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }
  
  /// Save token expiry
  static Future<void> saveTokenExpiry(DateTime expiry) async {
    await _storage.write(key: _tokenExpiryKey, value: expiry.toIso8601String());
  }
  
  /// Get token expiry
  static Future<DateTime?> getTokenExpiry() async {
    final expiryString = await _storage.read(key: _tokenExpiryKey);
    if (expiryString != null) {
      return DateTime.tryParse(expiryString);
    }
    return null;
  }
  
  /// Delete token expiry
  static Future<void> deleteTokenExpiry() async {
    await _storage.delete(key: _tokenExpiryKey);
  }
  
  /// Clear all auth data for current environment
  static Future<void> clearAllAuthData() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _tokenExpiryKey);
  }
  
  /// Clear all auth data for ALL environments
  static Future<void> clearAllEnvironmentAuthData() async {
    // Clear stage tokens
    await _storage.delete(key: 'access_token_stage');
    await _storage.delete(key: 'refresh_token_stage');
    await _storage.delete(key: 'token_expiry_stage');
    
    // Clear prod tokens
    await _storage.delete(key: 'access_token_prod');
    await _storage.delete(key: 'refresh_token_prod');
    await _storage.delete(key: 'token_expiry_prod');
    
    // Clear legacy non-environment-specific tokens
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'token_expiry');
  }
  
  /// Check if token is expired
  static Future<bool> isTokenExpired() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry);
  }
  
  /// Migrate old tokens to environment-specific storage
  static Future<void> migrateOldTokens() async {
    // Check for legacy tokens without environment suffix
    final oldAccessToken = await _storage.read(key: 'access_token');
    final oldRefreshToken = await _storage.read(key: 'refresh_token');
    final oldTokenExpiry = await _storage.read(key: 'token_expiry');
    
    if (oldAccessToken != null || oldRefreshToken != null) {
      // Migrate to current environment
      if (oldAccessToken != null) {
        await saveAccessToken(oldAccessToken);
      }
      if (oldRefreshToken != null) {
        await saveRefreshToken(oldRefreshToken);
      }
      if (oldTokenExpiry != null) {
        await _storage.write(key: _tokenExpiryKey, value: oldTokenExpiry);
      }
      
      // Clear old tokens
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
      await _storage.delete(key: 'token_expiry');
    }
  }
  
  /// Clear old environment tokens
  static Future<void> clearOldEnvironmentTokens() async {
    await clearAllEnvironmentAuthData();
  }
}