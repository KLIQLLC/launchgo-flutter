import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../api/api_service.dart';
import '../api/dio_client.dart';
import '../api/models/auth_request.dart';
import '../config/environment.dart';
import 'secure_storage_service.dart';

/// Service for managing user authentication with Google Sign-In and backend JWT tokens
class AuthService extends ChangeNotifier {
  GoogleSignInAccount? _currentUser;
  String? _accessToken;
  bool _isInitialized = false;
  bool _isSigningIn = false;
  Completer<void>? _signInCompleter;
  ApiService? _apiService;

  // Getters
  GoogleSignInAccount? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  bool get isInitialized => _isInitialized;
  bool get isSigningIn => _isSigningIn;
  bool get isAuthenticated => _currentUser != null;
  bool get hasAccessToken => _accessToken != null;

  // Google Sign-In configuration
  static const List<String> _scopes = [
    'email',
    'profile',
    'openid',
    'https://www.googleapis.com/auth/calendar',
  ];
  
  static const String _serverClientId = '481027521494-t3b8vqe1o9nfrejek745uji6q1ed6dgi.apps.googleusercontent.com';

  /// Initialize the authentication service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize API client
    if (_apiService == null) {
      final dio = DioClient.createDio();
      _apiService = ApiService(dio, baseUrl: EnvironmentConfig.baseUrl);
    }
    
    // Migrate old tokens to environment-specific storage
    await SecureStorageService.migrateOldTokens();
    
    // Load stored access token for current environment
    _accessToken = await SecureStorageService.getAccessToken();
    
    // Verify token validity
    if (_accessToken != null) {
      final isExpired = await SecureStorageService.isTokenExpired();
      if (isExpired) {
        _accessToken = null;
        await SecureStorageService.clearAllAuthData();
      }
    }
    
    try {
      final GoogleSignIn signIn = GoogleSignIn.instance;
      
      // Initialize with serverClientId for backend authentication
      await signIn.initialize(serverClientId: _serverClientId);
      
      // Listen for authentication events
      signIn.authenticationEvents.listen(_handleAuthenticationEvent);
      
      // Attempt silent sign-in only if we have a valid token
      if (_accessToken != null && !JwtDecoder.isExpired(_accessToken!)) {
        await _attemptSilentSignIn();
        
        // Request new token if needed
        if (_currentUser != null && (_accessToken == null || JwtDecoder.isExpired(_accessToken!))) {
          try {
            await requestServerAuthorization();
          } catch (e) {
            await signOut();
          }
        }
      } else if (_accessToken != null && JwtDecoder.isExpired(_accessToken!)) {
        // Clear expired tokens
        await SecureStorageService.clearAllAuthData();
        _accessToken = null;
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (error) {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Attempt silent sign-in without UI
  Future<void> _attemptSilentSignIn() async {
    try {
      await GoogleSignIn.instance.attemptLightweightAuthentication();
      
      if (_currentUser != null && shouldRequestServerAuth()) {
        // User will need to explicitly sign in to get backend token
      }
    } catch (error) {
      // Silent sign-in failure is expected for new users
    }
  }

  /// Handle Google Sign-In authentication events
  Future<void> _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) async {
    final user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    _currentUser = user;
    
    if (user != null && _accessToken == null) {
      try {
        await requestServerAuthorization();
      } catch (e) {
        // Failed to get backend token
      }
      
      _signInCompleter?.complete();
      _signInCompleter = null;
    }
    
    notifyListeners();
  }

  /// Sign in with Google
  Future<bool> signIn() async {
    if (_isSigningIn) {
      await _signInCompleter?.future;
      return _currentUser != null;
    }

    _isSigningIn = true;
    _signInCompleter = Completer<void>();
    notifyListeners();

    try {
      await GoogleSignIn.instance.authenticate();
      await _signInCompleter?.future;
      
      final success = _currentUser != null;
      _isSigningIn = false;
      notifyListeners();
      
      return success;
    } catch (error) {
      _isSigningIn = false;
      _signInCompleter?.completeError(error);
      _signInCompleter = null;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
      _currentUser = null;
      _accessToken = null;
      await SecureStorageService.clearAllAuthData();
      notifyListeners();
    } catch (error) {
      // Handle sign out error
    }
  }

  /// Disconnect Google account
  Future<void> disconnect() async {
    try {
      await GoogleSignIn.instance.disconnect();
      _currentUser = null;
      _accessToken = null;
      await SecureStorageService.clearAllAuthData();
      notifyListeners();
    } catch (error) {
      // Handle disconnect error
    }
  }

  /// Request server authorization from backend
  Future<void> requestServerAuthorization() async {
    if (_currentUser == null) return;
    
    try {
      await _getServerAuthCode(_currentUser!);
    } catch (e) {
      rethrow;
    }
  }

  /// Get server auth code from Google
  Future<void> _getServerAuthCode(GoogleSignInAccount user) async {
    // Skip if we already have a valid token
    if (_accessToken != null) {
      final isExpired = await SecureStorageService.isTokenExpired();
      if (!isExpired) return;
    }
    
    final authClient = user.authorizationClient;
    if (authClient == null) return;
    
    final serverAuth = await authClient.authorizeServer(_scopes);
    
    if (serverAuth != null) {
      await _sendServerAuthCodeToBackend(serverAuth.serverAuthCode);
    }
  }

  /// Send auth code to backend for JWT token
  Future<void> _sendServerAuthCodeToBackend(String serverAuthCode) async {
    final request = GoogleAuthRequest(code: serverAuthCode);
    
    try {
      final dio = DioClient.createDio();
      dio.options.baseUrl = EnvironmentConfig.baseUrl;
      
      final rawResponse = await dio.post(
        '/users/auth/google/mobile',
        data: request.toJson(),
      );
      
      Map<String, dynamic> responseData;
      if (rawResponse.data is String) {
        responseData = json.decode(rawResponse.data);
      } else {
        responseData = rawResponse.data;
      }
      
      // Handle different response formats between environments
      String? accessToken;
      int? expiresIn;
      
      if (responseData['user'] != null && responseData['user']['accessToken'] != null) {
        // Prod format: { user: { accessToken: "...", expiresIn: 123 } }
        accessToken = responseData['user']['accessToken'];
        expiresIn = responseData['user']['expiresIn'] as int?;
      } else if (responseData['data'] != null && responseData['data']['accessToken'] != null) {
        // Stage format: { data: { accessToken: "..." } }
        accessToken = responseData['data']['accessToken'];
        expiresIn = responseData['data']['expiresIn'] as int?;
      }
      
      if (accessToken != null) {
        _accessToken = accessToken;
        
        // Store token securely
        await SecureStorageService.saveAccessToken(_accessToken!);
        
        // Store token expiry if available
        if (expiresIn != null) {
          final expiry = DateTime.now().add(Duration(seconds: expiresIn));
          await SecureStorageService.saveTokenExpiry(expiry);
        }
        
        notifyListeners();
      }
    } catch (error) {
      rethrow;
    }
  }

  /// Check if server authorization is needed
  bool shouldRequestServerAuth() {
    return _currentUser != null && _accessToken == null;
  }

  /// Force re-authentication
  Future<bool> forceReAuthentication() async {
    await signOut();
    await Future.delayed(const Duration(milliseconds: 500));
    return await signIn();
  }

  /// Clear tokens for environment switching
  Future<void> clearEnvironmentTokens() async {
    await SecureStorageService.clearOldEnvironmentTokens();
    _accessToken = null;
    notifyListeners();
  }

  /// Set API service for dependency injection
  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }
}