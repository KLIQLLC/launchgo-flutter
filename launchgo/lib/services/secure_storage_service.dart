import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:launchgo/config/environment.dart';
import 'package:launchgo/models/user_model.dart';

/// Service for secure storage of authentication tokens with environment-specific keys
class SecureStorageService {
  /// iOS CallKit/PushKit can wake the app while the device is locked.
  /// The default Keychain accessibility ("when unlocked") makes reads fail in that state,
  /// which breaks accepting/joining calls in the background.
  ///
  /// Using "after first unlock" keeps values readable while locked *after the device was unlocked once*
  /// since boot — the common expected behavior for VoIP apps.
  static final FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: const IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Legacy storage (default options). Used only to migrate existing items.
  static final FlutterSecureStorage _legacyStorage = FlutterSecureStorage();
  
  /// Get environment-specific storage key
  static String _getEnvironmentKey(String baseKey) {
    final env = EnvironmentConfig.isStage ? 'stage' : 'prod';
    return '${baseKey}_$env';
  }
  
  // Storage keys (environment-specific)
  static String get _accessTokenKey => _getEnvironmentKey('access_token');
  static String get _refreshTokenKey => _getEnvironmentKey('refresh_token');
  static String get _tokenExpiryKey => _getEnvironmentKey('token_expiry');

  // Cached Stream Video bootstrap (so CallKit accept can initialize StreamVideo without waiting for full userInfo API).
  static String get _streamVideoBootstrapKey => _getEnvironmentKey('stream_video_bootstrap_v1');

  /// Best-effort migration: if tokens were previously written with the legacy (locked-only) accessibility,
  /// rewrite them with "after first unlock" accessibility so they are readable on lock screen wakes.
  static Future<void> migrateIOSKeychainAccessibilityIfNeeded() async {
    // iOS-only behavior, but guard for safety.
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      // If we can already read the access token using the new storage, assume migration is done.
      final alreadyReadable = await _storage.read(key: _accessTokenKey);
      if (alreadyReadable != null && alreadyReadable.isNotEmpty) return;

      final oldAccess = await _legacyStorage.read(key: _accessTokenKey);
      final oldRefresh = await _legacyStorage.read(key: _refreshTokenKey);
      final oldExpiry = await _legacyStorage.read(key: _tokenExpiryKey);
      final oldBootstrap = await _legacyStorage.read(key: _streamVideoBootstrapKey);

      if (oldAccess == null &&
          oldRefresh == null &&
          oldExpiry == null &&
          oldBootstrap == null) {
        return;
      }

      // Rewrite under the new storage (delete first to ensure attributes update).
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _tokenExpiryKey);
      await _storage.delete(key: _streamVideoBootstrapKey);

      if (oldAccess != null) {
        await _storage.write(key: _accessTokenKey, value: oldAccess);
      }
      if (oldRefresh != null) {
        await _storage.write(key: _refreshTokenKey, value: oldRefresh);
      }
      if (oldExpiry != null) {
        await _storage.write(key: _tokenExpiryKey, value: oldExpiry);
      }
      if (oldBootstrap != null) {
        await _storage.write(key: _streamVideoBootstrapKey, value: oldBootstrap);
      }
    } catch (_) {
      // Best effort: never break app startup due to migration.
    }
  }

  /// Cache a minimal "bootstrap user" for Stream Video initialization during CallKit accepts.
  ///
  /// This intentionally stores only what `StreamVideoService.initialize()` needs:
  /// id/name/email/role/callGetStreamToken/avatarUrl.
  static Future<void> saveStreamVideoBootstrapUser(UserModel user) async {
    final token = user.callGetStreamToken;
    if (token == null || token.isEmpty) return;

    final payload = <String, dynamic>{
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'role': user.role.name,
      'avatarUrl': user.avatarUrl,
      'callGetStreamToken': token,
    };
    await _storage.write(
      key: _streamVideoBootstrapKey,
      value: jsonEncode(payload),
    );
  }

  /// Load cached bootstrap user for Stream Video initialization.
  static Future<UserModel?> getStreamVideoBootstrapUser() async {
    try {
      final raw = await _storage.read(key: _streamVideoBootstrapKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final map = Map<String, dynamic>.from(decoded);
      final id = (map['id'] as String?) ?? '';
      final name = (map['name'] as String?) ?? '';
      final email = (map['email'] as String?) ?? '';
      final roleStr = (map['role'] as String?) ?? 'unknown';
      final avatarUrl = map['avatarUrl'] as String?;
      final callToken = map['callGetStreamToken'] as String?;

      if (id.isEmpty || name.isEmpty || callToken == null || callToken.isEmpty) {
        return null;
      }

      final role = switch (roleStr) {
        'student' => UserRole.student,
        'mentor' => UserRole.mentor,
        'caseManager' => UserRole.caseManager,
        _ => UserRole.unknown,
      };

      return UserModel(
        id: id,
        name: name,
        email: email,
        role: role,
        status: UserStatus.unknown,
        avatarUrl: avatarUrl,
        callGetStreamToken: callToken,
      );
    } catch (_) {
      return null;
    }
  }
  
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