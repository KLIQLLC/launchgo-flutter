import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
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

  // Video call credentials keys (for background push handling)
  static String get _videoCallUserIdKey => _getEnvironmentKey('video_call_user_id');
  static String get _videoCallUserNameKey => _getEnvironmentKey('video_call_user_name');
  static String get _videoCallTokenKey => _getEnvironmentKey('video_call_token');
  
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

  /// Save video call credentials (for background push handling)
  static Future<void> saveVideoCallCredentials({
    required String userId,
    required String userName,
    required String token,
  }) async {
    await _storage.write(key: _videoCallUserIdKey, value: userId);
    await _storage.write(key: _videoCallUserNameKey, value: userName);
    await _storage.write(key: _videoCallTokenKey, value: token);
  }

  /// Get video call credentials (for background push handling)
  static Future<Map<String, String>?> getVideoCallCredentials() async {
    final userId = await _storage.read(key: _videoCallUserIdKey);
    final userName = await _storage.read(key: _videoCallUserNameKey);
    final token = await _storage.read(key: _videoCallTokenKey);

    if (userId != null && userName != null && token != null) {
      return {
        'userId': userId,
        'userName': userName,
        'token': token,
      };
    }
    return null;
  }

  /// Delete video call credentials
  static Future<void> deleteVideoCallCredentials() async {
    await _storage.delete(key: _videoCallUserIdKey);
    await _storage.delete(key: _videoCallUserNameKey);
    await _storage.delete(key: _videoCallTokenKey);
  }

  // Pending accepted call storage (for handling call accept from terminated state)
  static const String _pendingCallIdKey = 'pending_accepted_call_id';
  // Pending ringing call storage (tracks incoming call shown via push)
  static const String _pendingRingingCallIdKey = 'pending_ringing_call_id';

  /// Save pending accepted call ID (when user accepts call while app is starting)
  static Future<void> savePendingAcceptedCallId(String callId) async {
    await _storage.write(key: _pendingCallIdKey, value: callId);
  }

  /// Get pending accepted call ID
  static Future<String?> getPendingAcceptedCallId() async {
    return await _storage.read(key: _pendingCallIdKey);
  }

  /// Delete pending accepted call ID
  static Future<void> deletePendingAcceptedCallId() async {
    await _storage.delete(key: _pendingCallIdKey);
  }

  /// Save pending ringing call ID (when incoming call UI is shown from push)
  static Future<void> savePendingRingingCallId(String callId) async {
    await _storage.write(key: _pendingRingingCallIdKey, value: callId);
  }

  /// Get pending ringing call ID
  static Future<String?> getPendingRingingCallId() async {
    return await _storage.read(key: _pendingRingingCallIdKey);
  }

  /// Delete pending ringing call ID
  static Future<void> deletePendingRingingCallId() async {
    await _storage.delete(key: _pendingRingingCallIdKey);
  }

  /// Clear all auth data for current environment
  static Future<void> clearAllAuthData() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _tokenExpiryKey);
    await deleteVideoCallCredentials();
  }
  
  /// Clear all auth data for ALL environments
  static Future<void> clearAllEnvironmentAuthData() async {
    // Clear stage tokens
    await _storage.delete(key: 'access_token_stage');
    await _storage.delete(key: 'refresh_token_stage');
    await _storage.delete(key: 'token_expiry_stage');
    await _storage.delete(key: 'video_call_user_id_stage');
    await _storage.delete(key: 'video_call_user_name_stage');
    await _storage.delete(key: 'video_call_token_stage');

    // Clear prod tokens
    await _storage.delete(key: 'access_token_prod');
    await _storage.delete(key: 'refresh_token_prod');
    await _storage.delete(key: 'token_expiry_prod');
    await _storage.delete(key: 'video_call_user_id_prod');
    await _storage.delete(key: 'video_call_user_name_prod');
    await _storage.delete(key: 'video_call_token_prod');

    // Clear legacy non-environment-specific tokens
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'token_expiry');
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