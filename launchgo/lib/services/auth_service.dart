import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  GoogleSignInAccount? _currentUser;
  bool _isInitialized = false;
  bool _isSigningIn = false;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isSigningIn => _isSigningIn;
  bool get isAuthenticated => _currentUser != null;

  static const List<String> _scopes = [
    'email',
    'profile',
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final GoogleSignIn signIn = GoogleSignIn.instance;
      
      await signIn.initialize();
      signIn.authenticationEvents.listen(_handleAuthenticationEvent);
      
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
    notifyListeners();
  }

  Future<bool> signIn() async {
    if (!_isInitialized || _isSigningIn) return false;

    _isSigningIn = true;
    notifyListeners();

    try {
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        await GoogleSignIn.instance.authenticate(
          scopeHint: _scopes,
        );
        return true;
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
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.disconnect();
      _currentUser = null;
      notifyListeners();
    } catch (error) {
      debugPrint('Sign out error: $error');
    }
  }
}