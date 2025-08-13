import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  GoogleSignInAccount? _currentUser;
  String? _idToken;
  String? _serverAuthCode;
  String? _sessionToken; // Backend session token
  bool _isInitialized = false;
  bool _isSigningIn = false;
  bool _serverAuthCodeSent = false; // Track if we've sent the code to backend
  Completer<void>? _signInCompleter;

  GoogleSignInAccount? get currentUser => _currentUser;
  String? get idToken => _idToken;
  String? get serverAuthCode => _serverAuthCode;
  String? get sessionToken => _sessionToken;
  bool get isInitialized => _isInitialized;
  bool get isSigningIn => _isSigningIn;
  bool get isAuthenticated => _currentUser != null;

  static const List<String> _scopes = [
    'email',
    'profile',
    'openid',
    'https://www.googleapis.com/auth/calendar',
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
      
      // Don't attempt automatic sign-in on app launch to prevent Safari redirects
      // Users should explicitly tap the sign-in button
      // await signIn.attemptLightweightAuthentication();
      
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
  
  Future<void> _getServerAuthCode(GoogleSignInAccount user) async {
    try {
      // Skip if we've already sent the serverAuthCode to backend
      if (_serverAuthCodeSent) {
        debugPrint('Server auth code already sent to backend, skipping');
        return;
      }
      
      // Check if authorizationClient is available
      if (user.authorizationClient != null) {
        // Use authorizationClient to get serverAuthCode
         // Authorization with scopes - this shows the Google login form
        final GoogleSignInServerAuthorization? serverAuth = 
            await user.authorizationClient!.authorizeServer(
          _scopes, // Pass the scopes as required parameter
        );
        
        if (serverAuth != null && serverAuth.serverAuthCode != null) {
          _serverAuthCode = serverAuth.serverAuthCode;
          debugPrint('Server Auth Code received: $_serverAuthCode');
          
          // Send to backend immediately as it's only valid once
          await _sendServerAuthCodeToBackend(_serverAuthCode!);
          _serverAuthCodeSent = true; // Mark as sent
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
          
          // After successful sign-in, check if we need serverAuthCode
          // Only request it if we haven't sent it to backend yet
          if (!_serverAuthCodeSent) {
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
  
  // Separate method to request server authorization
  // This will show another prompt but only when explicitly needed
  Future<bool> requestServerAuthorization() async {
    if (_currentUser == null) {
      debugPrint('No user signed in, cannot request server authorization');
      return false;
    }
    
    if (_serverAuthCodeSent) {
      debugPrint('Server auth code already sent, skipping');
      return true;
    }
    
    try {
      await _getServerAuthCode(_currentUser!);
      return _serverAuthCodeSent;
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
      _idToken = null;
      _serverAuthCode = null;
      _sessionToken = null; // Clear session token
      // Don't reset _serverAuthCodeSent on regular sign out
      // Only reset it on disconnect when user wants to re-authorize
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
      _idToken = null;
      _serverAuthCode = null;
      _sessionToken = null; // Clear session token
      _serverAuthCodeSent = false; // Reset on disconnect for fresh authorization
      notifyListeners();
    } catch (error) {
      debugPrint('Disconnect error: $error');
    }
  }
  
  Future<void> _sendServerAuthCodeToBackend(String serverAuthCode) async {
    // TODO: Implement this method to send serverAuthCode to your backend
    // IMPORTANT: This code can only be used ONCE to exchange for tokens
    
    // The backend should:
    // 1. Exchange serverAuthCode for refresh + access tokens using Google OAuth2 API
    // 2. Store the refresh token securely (encrypted in database)
    // 3. Use refresh token to get new access tokens when needed
    // 4. Return a session token to the app
    
    // Example:
    // try {
    //   final response = await http.post(
    //     Uri.parse('https://your-backend.com/auth/google/exchange'),
    //     headers: {'Content-Type': 'application/json'},
    //     body: json.encode({
    //       'serverAuthCode': serverAuthCode,
    //       'platform': Platform.isIOS ? 'ios' : 'android',
    //     }),
    //   );
    //   
    //   if (response.statusCode == 200) {
    //     final data = json.decode(response.body);
    //     // Store session token for API authentication
    //     _sessionToken = data['sessionToken'];
    //     notifyListeners();
    //     debugPrint('Server auth code exchanged successfully');
    //   } else {
    //     throw Exception('Failed to exchange auth code: ${response.statusCode}');
    //   }
    // } catch (e) {
    //   debugPrint('Failed to send server auth code: $e');
    //   _serverAuthCodeSent = false; // Reset on failure to allow retry
    //   rethrow;
    // }
    
    debugPrint('TODO: Send serverAuthCode to backend for exchange');
    debugPrint('Note: This code can only be used ONCE. Backend must exchange it immediately.');
  }
}