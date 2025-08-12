import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  GoogleSignInAccount? _currentUser;
  String? _idToken;
  String? _serverAuthCode;
  bool _isInitialized = false;
  bool _isSigningIn = false;
  Completer<void>? _signInCompleter;

  GoogleSignInAccount? get currentUser => _currentUser;
  String? get idToken => _idToken;
  String? get serverAuthCode => _serverAuthCode;
  bool get isInitialized => _isInitialized;
  bool get isSigningIn => _isSigningIn;
  bool get isAuthenticated => _currentUser != null;

  static const List<String> _scopes = [
    'email',
    'profile',
    'openid',
  ];
  
  // Web Client ID from Google Cloud Console
  // This enables serverAuthCode for backend authentication
  static const String _serverClientId = '1068871581972-77k12p5vsv02qf93a23b2bl7eolnlo23.apps.googleusercontent.com';

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final GoogleSignIn signIn = GoogleSignIn.instance;
      
      // Initialize with serverClientId for serverAuthCode support
      // Note: v7.1.1 requires serverClientId to be set for serverAuthCode
      await signIn.initialize(
        serverClientId: _serverClientId,
      );

      // Listen for authentication events
      signIn.authenticationEvents.listen(_handleAuthenticationEvent);
      
      // Try to sign in silently
      await signIn.attemptLightweightAuthentication();
      
      _isInitialized = true;
      notifyListeners();
    } catch (error) {
      debugPrint('Google Sign-In initialization error: $error');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) async {
    final user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    _currentUser = user;
    
    if (user != null) {
      // Try to get serverAuthCode if available
      // Note: In v7.1.1, serverAuthCode might not be directly accessible
      // You may need to handle this differently or upgrade the package
      await _retrieveTokens();
      
      // Log user info for debugging
      debugPrint('User signed in: ${user.email}');
      debugPrint('User ID: ${user.id}');
      
      // Complete sign in if we're waiting for it
      _signInCompleter?.complete();
      _signInCompleter = null;
    } else {
      _idToken = null;
      _serverAuthCode = null;
    }
    
    notifyListeners();
  }
  
  Future<void> _retrieveTokens() async {
    try {
      final GoogleSignInAuthentication auth = await _currentUser!.authentication;
      _idToken = auth.idToken;
      
      debugPrint('ID Token retrieved: ${_idToken != null}');
      
      // For backend authentication, you can use the ID token
      // The backend can verify this token with Google's public keys
      if (_idToken != null) {
        // Send ID token to backend for verification
        await _sendIdTokenToBackend(_idToken!);
      }
    } catch (error) {
      debugPrint('Error retrieving tokens: $error');
      _idToken = null;
    }
  }

  Future<bool> signIn() async {
    if (!_isInitialized || _isSigningIn) return false;

    _isSigningIn = true;
    notifyListeners();

    try {
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        // Create a completer to wait for the authentication event
        _signInCompleter = Completer<void>();
        
        // Authenticate with scopes
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

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.disconnect();
      _currentUser = null;
      _idToken = null;
      _serverAuthCode = null;
      notifyListeners();
    } catch (error) {
      debugPrint('Sign out error: $error');
    }
  }
  
  Future<String?> getValidIdToken() async {
    if (_currentUser == null) return null;
    
    try {
      final GoogleSignInAuthentication auth = await _currentUser!.authentication;
      _idToken = auth.idToken;
      return _idToken;
    } catch (error) {
      debugPrint('Error getting valid token: $error');
      return null;
    }
  }
  
  Future<void> _sendIdTokenToBackend(String idToken) async {
    // TODO: Implement this method to send ID token to your backend
    // The backend should:
    // 1. Verify the ID token with Google's public keys
    // 2. Extract user information from the token
    // 3. Create or update user session
    // 4. Return session token to the app
    
    // Example:
    // try {
    //   final response = await http.post(
    //     Uri.parse('https://your-backend.com/auth/google/verify'),
    //     headers: {'Content-Type': 'application/json'},
    //     body: json.encode({'idToken': idToken}),
    //   );
    //   
    //   if (response.statusCode == 200) {
    //     final data = json.decode(response.body);
    //     // Store session token, user info, etc.
    //     debugPrint('Authentication successful');
    //   }
    // } catch (e) {
    //   debugPrint('Failed to authenticate with backend: $e');
    // }
    
    debugPrint('TODO: Send ID token to backend for verification');
  }
  
  Future<void> _sendServerAuthCodeToBackend(String serverAuthCode) async {
    // NOTE: serverAuthCode might not be available in v7.1.1
    // If you need serverAuthCode functionality, consider:
    // 1. Upgrading to a newer version of google_sign_in
    // 2. Using Firebase Auth which handles this automatically
    // 3. Using the ID token for backend authentication instead
    
    debugPrint('Server auth code functionality not available in v7.1.1');
  }
}