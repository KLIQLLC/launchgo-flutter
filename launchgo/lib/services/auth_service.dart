import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../api/api_service.dart';
import '../api/dio_client.dart';
import '../api/models/auth_request.dart';
import 'secure_storage_service.dart';

class AuthService extends ChangeNotifier {
  GoogleSignInAccount? _currentUser;
  String? _accessToken; // JWT access token from backend
  bool _isInitialized = false;
  bool _isSigningIn = false;
  Completer<void>? _signInCompleter;
  
  // API client - can be injected or created internally
  ApiService? _apiService;

  GoogleSignInAccount? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  bool get isInitialized => _isInitialized;
  bool get isSigningIn => _isSigningIn;
  // Check if user is authenticated
  // For now, we allow navigation with just Google sign-in
  // The accessToken will be obtained asynchronously after sign-in
  bool get isAuthenticated => _currentUser != null;
  bool get hasAccessToken => _accessToken != null;
  
  // Setter for dependency injection
  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }

  static const List<String> _scopes = [
    'email',
    'profile',
    'openid',
    'https://www.googleapis.com/auth/calendar',
  ];
  
  // Web Client ID from Google Cloud Console
  // This enables serverAuthCode for backend authentication
  static const String _serverClientId = '481027521494-t3b8vqe1o9nfrejek745uji6q1ed6dgi.apps.googleusercontent.com';

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize API client if not injected
    if (_apiService == null) {
      final dio = DioClient.createDio();
      _apiService = ApiService(dio);
    }
    
    // Load stored access token
    _accessToken = await SecureStorageService.getAccessToken();
    if (_accessToken != null) {
      debugPrint('Loaded access token from secure storage');
      // Optionally verify token is still valid
      final isExpired = await SecureStorageService.isTokenExpired();
      if (isExpired) {
        debugPrint('Stored token is expired, clearing...');
        _accessToken = null;
        await SecureStorageService.clearAllAuthData();
      }
    }
    
    try {
      final GoogleSignIn signIn = GoogleSignIn.instance;
      
      // Initialize with serverClientId for serverAuthCode support
      // Note: v7.1.1 requires serverClientId to be set for serverAuthCode
      await signIn.initialize(
        serverClientId: _serverClientId,
      );

      // Listen for authentication events
      signIn.authenticationEvents.listen(_handleAuthenticationEvent);
      
      // Attempt silent sign-in (won't show any UI)
      // This only works if user previously signed in and hasn't revoked access
      await _attemptSilentSignIn();
      
      _isInitialized = true;
      notifyListeners();
    } catch (error) {
      debugPrint('Google Sign-In initialization error: $error');
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  Future<void> _attemptSilentSignIn() async {
    try {
      debugPrint('Attempting silent sign-in...');
      
      // This tries to sign in without showing any UI
      // Only works if user has previously authorized the app
      await GoogleSignIn.instance.attemptLightweightAuthentication();
      
      // If successful, _handleAuthenticationEvent will be called
      // and _currentUser will be set
      if (_currentUser != null) {
        debugPrint('Silent sign-in successful: ${_currentUser!.email}');
        
        // For silent sign-in, we DON'T request serverAuthCode
        // because that would show a prompt. The backend should:
        // 1. Use stored refresh token from previous serverAuthCode exchange
        // 2. Or work with ID tokens only for returning users
      } else {
        debugPrint('Silent sign-in failed - user needs to sign in manually');
      }
    } catch (error) {
      debugPrint('Silent sign-in error: $error');
      // Silent sign-in failure is expected for new users
      // Don't throw error, just continue without signed-in user
    }
  }

  Future<void> _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) async {
    final user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    _currentUser = user;
    
    if (user != null) {
      // Log user info for debugging
      debugPrint('User signed in: ${user.email}');
      debugPrint('User ID: ${user.id}');
      
      // Complete sign in if we're waiting for it
      _signInCompleter?.complete();
      _signInCompleter = null;
    }
    
    notifyListeners();
  }
  
  Future<void> _getServerAuthCode(GoogleSignInAccount user) async {
    try {
      // Skip if we already have a valid access token
      if (_accessToken != null) {
        final isExpired = await SecureStorageService.isTokenExpired();
        if (!isExpired) {
          debugPrint('Valid access token already exists, skipping server auth code request');
          return;
        }
      }
      
      // Check if authorizationClient is available
      final authClient = user.authorizationClient;
      if (authClient != null) {
        // Use authorizationClient to get serverAuthCode
         // Authorization with scopes - this shows the Google login form
        final GoogleSignInServerAuthorization? serverAuth = 
            await authClient.authorizeServer(
          _scopes, // Pass the scopes as required parameter
        );
        
        if (serverAuth != null) {
          final serverAuthCode = serverAuth.serverAuthCode;
          debugPrint('Server Auth Code received: $serverAuthCode');
          
          // Send to backend immediately as it's only valid once
          await _sendServerAuthCodeToBackend(serverAuthCode);
        } else {
          debugPrint('No server authorization returned from authorizeServer');
        }
      } else {
        debugPrint('Authorization client not available for this user');
      }
    } catch (error) {
      debugPrint('Error getting server auth code: $error');
    }
  }

  Future<bool> signIn() async {
    // Guard against multiple sign-in attempts and redundant sign-ins
    if (!_isInitialized || _isSigningIn || _currentUser != null) {
      debugPrint('Sign in blocked: initialized=$_isInitialized, signingIn=$_isSigningIn, currentUser=${_currentUser != null}');
      return _currentUser != null;
    }

    _isSigningIn = true;
    notifyListeners();

    try {
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        // Create a completer to wait for the authentication event
        _signInCompleter = Completer<void>();
        
        // Authenticate with scopes - this shows the Google login form
        await GoogleSignIn.instance.authenticate(
          scopeHint: _scopes,
        );
        
        // Wait for the authentication event to be processed
        // This will complete when _handleAuthenticationEvent receives the user
        await _signInCompleter?.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('Sign in timeout - no authentication event received');
          },
        );
        
        // Check if authentication was successful
        if (_currentUser != null) {
          debugPrint('Sign in successful for: ${_currentUser!.email}');
          
          // TODO: Uncomment when backend integration is ready
          // After successful sign-in, check if we need serverAuthCode
          // Only request it for first-time users or when backend needs it
          if (shouldRequestServerAuth()) {
            // Show a dialog explaining why we need additional permission
            // Then request server authorization
            await requestServerAuthorization();
          }
          
          return true;
        } else {
          debugPrint('Sign in completed but no user available');
          return false;
        }
      } else {
        throw UnsupportedError('Authentication not supported on this platform');
      }
    } on GoogleSignInException catch (e) {
      debugPrint('Sign in failed: ${e.code.name} - ${e.description}');
      return false;
    } catch (error) {
      debugPrint('Sign in failed: ${error.toString()}');
      return false;
    } finally {
      _isSigningIn = false;
      _signInCompleter = null;
      notifyListeners();
    }
  }
  
  // TODO: Uncomment and use when backend integration is ready
  // Determine if we should request server authorization
  bool shouldRequestServerAuth() {
    // You can customize this logic based on your needs:
    // - Check if user is new (first sign-in)
    // - Check if backend has valid refresh token
    // - Check if user wants to use Google Calendar features
    
    // Request server auth if we don't have a valid access token
    return _accessToken == null;
  }
  
  // Separate method to request server authorization
  // This will show another prompt but only when explicitly needed
  Future<bool> requestServerAuthorization() async {
    if (_currentUser == null) {
      debugPrint('No user signed in, cannot request server authorization');
      return false;
    }
    
    if (_accessToken != null) {
      final isExpired = await SecureStorageService.isTokenExpired();
      if (!isExpired) {
        debugPrint('Valid access token already exists, skipping');
        return true;
      }
    }
    
    try {
      await _getServerAuthCode(_currentUser!);
      return _accessToken != null;
    } catch (e) {
      debugPrint('Failed to get server authorization: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      // Use signOut() to maintain app authorization (prevents re-authorization prompts)
      // Use disconnect() only when you want to completely revoke authorization
      await GoogleSignIn.instance.signOut();
      _currentUser = null;
      _accessToken = null; // Clear access token
      
      // Clear token from secure storage
      await SecureStorageService.clearAllAuthData();
      
      notifyListeners();
    } catch (error) {
      debugPrint('Sign out error: $error');
    }
  }
  
  Future<void> disconnect() async {
    try {
      // This completely revokes the app's authorization
      await GoogleSignIn.instance.disconnect();
      _currentUser = null;
      _accessToken = null; // Clear access token
      
      // Clear token from secure storage
      await SecureStorageService.clearAllAuthData();
      
      notifyListeners();
    } catch (error) {
      debugPrint('Disconnect error: $error');
    }
  }
  
  Future<void> _sendServerAuthCodeToBackend(String serverAuthCode) async {
    // IMPORTANT: This code can only be used ONCE to exchange for tokens
    
    try {
      debugPrint('Sending serverAuthCode to backend...');
      
      // Create request object
      final request = GoogleAuthRequest(code: serverAuthCode);
      
      // Call API using Retrofit
      final response = await _apiService!.authenticateWithGoogle(request);
      
      // Extract the access token from the response
      if (response.data != null) {
        _accessToken = response.data!.accessToken;
        debugPrint('Server auth code exchanged successfully');
        debugPrint('Access token received (length: ${_accessToken!.length})');
        
        // Save token to secure storage
        await SecureStorageService.saveAccessToken(_accessToken!);
        
        // Decode JWT to get expiry time
        try {
          final decodedToken = JwtDecoder.decode(_accessToken!);
          debugPrint('Decoded JWT: email=${decodedToken['email']}, role=${decodedToken['role']}');
          
          // Get expiry from token (exp claim is in seconds since epoch)
          if (decodedToken.containsKey('exp')) {
            final expiryTimestamp = decodedToken['exp'] as int;
            final expiry = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp * 1000);
            await SecureStorageService.saveTokenExpiry(expiry);
            debugPrint('Token expires at: $expiry');
          }
        } catch (e) {
          debugPrint('Error decoding JWT: $e');
          // Fallback to 30 days expiry if decoding fails
          final expiry = DateTime.now().add(const Duration(days: 30));
          await SecureStorageService.saveTokenExpiry(expiry);
        }
        
        debugPrint('Access token saved to secure storage');
        
        // Notify listeners about the authentication state change
        notifyListeners();
      } else {
        throw Exception('Invalid response format: missing accessToken');
      }
    } on DioException catch (e) {
      debugPrint('Failed to send server auth code (DioException): ${e.message}');
      if (e.response != null) {
        debugPrint('Status code: ${e.response!.statusCode}');
        debugPrint('Response data: ${e.response!.data}');
      }
      rethrow;
    } catch (e) {
      debugPrint('Failed to send server auth code: $e');
      rethrow;
    }
  }
}