import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../api/dio_client.dart';
import 'api_service_retrofit.dart';
import '../config/environment.dart';
import '../models/user_model.dart';
import '../models/semester_model.dart';
import 'secure_storage_service.dart';
import 'permissions_service.dart';
import 'preferences_service.dart';
import 'chat/stream_chat_service.dart';
import 'push_notification_service.dart';

/// Service for managing user authentication with Google Sign-In and backend JWT tokens
class AuthService extends ChangeNotifier {
  GoogleSignInAccount? _currentUser;
  String? _accessToken;
  UserModel? _userInfo;
  String? _selectedStudentId;
  bool _isInitialized = false;
  bool _isSigningIn = false;
  Completer<void>? _signInCompleter;
  ApiServiceRetrofit? _apiService;
  StreamChatService? _streamChatService;

  // Getters
  GoogleSignInAccount? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  UserModel? get userInfo => _userInfo;
  String? get selectedStudentId => _selectedStudentId;
  bool get isInitialized => _isInitialized;
  bool get isSigningIn => _isSigningIn;
  bool get isAuthenticated => _accessToken != null && !(_accessToken != null ? JwtDecoder.isExpired(_accessToken!) : true);
  bool get hasAccessToken => _accessToken != null;
  
  // Role-based getters
  bool get isMentor => _userInfo?.isMentor ?? false;
  bool get isStudent => _userInfo?.isStudent ?? false;
  bool get isCaseManager => _userInfo?.isCaseManager ?? false;
  List<Student> get students => _userInfo?.students ?? [];
  
  // Semester-related getters
  List<Semester> get semesters => _userInfo?.semesters ?? [];
  String? get selectedSemesterId => _userInfo?.selectedSemesterId ?? PreferencesService.getSelectedSemesterId();
  
  // Permissions service
  PermissionsService get permissions => PermissionsService(_userInfo);

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
    
    // Initialize preferences service for user selections
    await PreferencesService.initialize();
    await PreferencesService.migrateOldPreferences();
    
    // Initialize API client
    if (_apiService == null) {
      _apiService = ApiServiceRetrofit(authService: this);
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
      
      // If we have a valid token, skip Google Sign-In and use stored credentials
      if (_accessToken != null && !JwtDecoder.isExpired(_accessToken!)) {
        
        // Load user info and semesters immediately for valid tokens
        debugPrint('🔐 Loading user data during initialization...');
        await loadUserInfo();
        
        // Register device for push notifications for existing authenticated users
        try {
          debugPrint('🔔 [FCM DEBUG] Registering device for existing authenticated user...');
          if (_apiService != null) {
            await PushNotificationService.instance.registerDevice(_apiService!);
            debugPrint('✅ [FCM DEBUG] Device registered for existing user');
          } else {
            debugPrint('⚠️ [FCM DEBUG] No API service available for device registration');
          }
        } catch (e) {
          debugPrint('❌ [FCM DEBUG] Failed to register device for existing user: $e');
          // Don't fail the initialization if device registration fails
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


  /// Handle Google Sign-In authentication events
  Future<void> _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) async {
    final user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    _currentUser = user;
    
    // Only request server authorization if user is signing in explicitly
    if (user != null && _accessToken == null && _signInCompleter != null) {
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
      // If already signed in with Google but no access token, 
      // just retry backend authentication
      if (_currentUser != null && _accessToken == null) {
        // User is already authenticated with Google, just need backend token
        await _getServerAuthCode(_currentUser!);
        _signInCompleter?.complete();
        await _signInCompleter?.future;
      } else {
        // Normal sign-in flow
        await GoogleSignIn.instance.authenticate();
        await _signInCompleter?.future;
      }
      
      final success = _currentUser != null && _accessToken != null;
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
  Future<void> signOut({StreamChatService? streamChatService}) async {
    try {
      // Unregister device before logout
      try {
        debugPrint('🔔 Unregistering device during logout...');
        if (_apiService != null) {
          await PushNotificationService.instance.unregisterDevice(_apiService!);
          debugPrint('✅ Device unregistered during logout');
        }
      } catch (e) {
        debugPrint('❌ [AUTH] Error unregistering device during logout: $e');
        // Don't fail logout if device unregistration fails
      }
      
      // Always try to disconnect from Stream Chat during logout
      // Try with provided service first, then try to get it from static instance
      StreamChatService? chatService = streamChatService ?? StreamChatService.instance;
      
      if (chatService != null) {
        try {
          await chatService.disconnectUser();
          debugPrint('🔴 [AUTH] Disconnected from Stream Chat during logout');
        } catch (e) {
          debugPrint('❌ [AUTH] Error disconnecting Stream Chat: $e');
        }
      } else {
        debugPrint('🟡 [AUTH] No StreamChatService available for disconnect');
      }
      
      await GoogleSignIn.instance.signOut();
      _currentUser = null;
      _accessToken = null;
      _userInfo = null;
      _selectedStudentId = null;
      
      // Clear secure storage and user preferences
      await SecureStorageService.clearAllAuthData();
      await PreferencesService.clearAllPreferences();
      
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
    try {
      debugPrint('🔐 [FCM DEBUG] Sending auth code to backend...');
      debugPrint('🔐 GET ${EnvironmentConfig.baseUrl}/users/auth/google/mobile?code=$serverAuthCode');
      
      // Use direct Dio call to get raw JSON response
      final dio = DioClient.createDio();
      dio.options.baseUrl = EnvironmentConfig.baseUrl;
      
      final rawResponse = await dio.get(
        '/users/auth/google/mobile',
        queryParameters: {'code': serverAuthCode},
      );
      debugPrint('🔐 Auth response received: ${rawResponse.statusCode}');
      
      Map<String, dynamic> responseData;
      if (rawResponse.data is String) {
        responseData = json.decode(rawResponse.data);
      } else {
        responseData = rawResponse.data;
      }
      
      // Direct response format: { accessToken: "...", expiresIn: 123 }
      final accessToken = responseData['accessToken'] as String?;
      final expiresIn = responseData['expiresIn'] as int?;
      
      if (accessToken != null) {
        debugPrint('🔐 Access token received successfully');
        _accessToken = accessToken;
        
        // Store token securely
        await SecureStorageService.saveAccessToken(_accessToken!);
        debugPrint('🔐 Token saved to secure storage');
        
        // Store token expiry if available
        if (expiresIn != null) {
          final expiry = DateTime.now().add(Duration(seconds: expiresIn));
          await SecureStorageService.saveTokenExpiry(expiry);
          debugPrint('🔐 Token expiry set to: $expiry');
        }
        
        notifyListeners();
        
        // Load user info after successful token storage
        debugPrint('🔐 Loading user info...');
        await loadUserInfo();
        
        // Register device for push notifications after successful login
        try {
          debugPrint('🔔 [FCM DEBUG] Registering device after successful login...');
          if (_apiService != null) {
            await PushNotificationService.instance.registerDevice(_apiService!);
            debugPrint('✅ [FCM DEBUG] Device registered after login');
          } else {
            debugPrint('⚠️ [FCM DEBUG] No API service available for device registration');
          }
        } catch (e) {
          debugPrint('❌ [FCM DEBUG] Failed to register device after login: $e');
          // Don't fail the login process if device registration fails
        }
        
        // Set user online after successful authentication
        if (_streamChatService != null && _streamChatService!.isUserConnected) {
          await _streamChatService!.setUserOnline();
          debugPrint('🟢 User set to ONLINE after authentication');
        }
        
        debugPrint('🔐 Sign-in complete!');
      } else {
        debugPrint('❌ No access token in response');
      }
    } catch (error) {
      debugPrint('❌ Error during authentication: $error');
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
  void setApiService(ApiServiceRetrofit apiService) {
    _apiService = apiService;
  }

  /// Set StreamChat service for presence management
  void setStreamChatService(StreamChatService streamChatService) {
    _streamChatService = streamChatService;
  }
  
  /// Load user information including role and students
  Future<void> loadUserInfo() async {
    if (_apiService == null) {
      _apiService = ApiServiceRetrofit(authService: this);
    }
    
    try {
      // Load user info first
      debugPrint('🔄 Calling getUserInfo API...');
      final userInfoData = await _apiService!.getUserInfo();
      if (userInfoData != null) {
        debugPrint('✅ User info data received: ${userInfoData['id']} - ${userInfoData['name']}');
        _userInfo = UserModel.fromJson(userInfoData);
        debugPrint('✅ User info parsed: ${_userInfo?.id} - ${_userInfo?.name} (${_userInfo?.role})');
        
        
        // Restore saved student selection for mentors
        if (_userInfo?.isMentor == true && _userInfo!.students.isNotEmpty) {
          final savedStudentId = PreferencesService.getSelectedStudentId();
          if (savedStudentId != null && 
              _userInfo!.students.any((s) => s.id == savedStudentId)) {
            // Restore previously selected student
            _selectedStudentId = savedStudentId;
            
            // Connect to Stream Chat if service is available
            if (_streamChatService != null && _userInfo!.getStreamToken != null) {
              _connectMentorToStreamChat(savedStudentId);
            }
          } else {
            // No saved selection - auto-select first student for better UX
            _selectedStudentId = _userInfo!.students.first.id;
            
            // Save the auto-selection for future app starts
            await PreferencesService.saveSelectedStudentId(_selectedStudentId!);
            
            // Connect to Stream Chat if service is available
            if (_streamChatService != null && _userInfo!.getStreamToken != null) {
              _connectMentorToStreamChat(_selectedStudentId!);
            }
          }
        }
      }
      
      // Load semesters separately from the new endpoint
      await loadSemesters();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load user info: $e');
    }
  }
  
  /// Refresh user information to get latest data (like updated GPA)
  Future<void> refreshUserInfo() async {
    if (_apiService == null) {
      _apiService = ApiServiceRetrofit(authService: this);
    }
    
    try {
      debugPrint('🔄 Refreshing user info...');
      final userInfoData = await _apiService!.getUserInfo();
      if (userInfoData != null) {
        final currentSelectedStudentId = _selectedStudentId;
        final currentSelectedSemesterId = _userInfo?.selectedSemesterId;
        final currentSemesters = _userInfo?.semesters ?? [];
        
        _userInfo = UserModel.fromJson(userInfoData);
        
        // Preserve the current student selection after refresh
        if (currentSelectedStudentId != null && 
            _userInfo!.students.any((s) => s.id == currentSelectedStudentId)) {
          _selectedStudentId = currentSelectedStudentId;
        }
        
        // Preserve the current semester selection and semesters list
        if (currentSemesters.isNotEmpty) {
          _userInfo = _userInfo!.copyWith(
            semesters: currentSemesters,
            selectedSemesterId: currentSelectedSemesterId,
          );
        }
        
        debugPrint('✅ User info refreshed with latest data');
      }
    } catch (e) {
      debugPrint('Failed to refresh user info: $e');
    }
  }
  
  /// Load semesters from the API
  Future<void> loadSemesters() async {
    if (_apiService == null) {
      _apiService = ApiServiceRetrofit(authService: this);
    }
    
    try {
      debugPrint('🔄 Loading semesters from API...');
      final semestersData = await _apiService!.getSemesters();
      debugPrint('✅ Received ${semestersData.length} semesters');
      
      if (semestersData.isNotEmpty && _userInfo != null) {
        debugPrint('📝 Parsing semesters...');
        final semesters = semestersData
            .map((s) => Semester.fromJson(s))
            .toList();
        debugPrint('✅ Parsed ${semesters.length} semesters: ${semesters.map((s) => s.name).join(', ')}');
        
        // Restore saved semester selection or use default/first semester
        String? selectedSemesterId;
        
        // Try to restore previously selected semester
        final savedSemesterId = PreferencesService.getSelectedSemesterId();
        debugPrint('🔄 Trying to restore saved semester: $savedSemesterId');
        
        if (savedSemesterId != null && 
            semesters.any((s) => s.id == savedSemesterId)) {
          selectedSemesterId = savedSemesterId;
          debugPrint('✅ Restored saved semester: $savedSemesterId');
        } else {
          debugPrint('⚠️ No saved semester found, using default/first');
          // Fall back to default semester or first available
          try {
            final defaultSemester = semesters.firstWhere((s) => s.isDefault);
            selectedSemesterId = defaultSemester.id;
          } catch (_) {
            // No default semester found, use first if available
            if (semesters.isNotEmpty) {
              selectedSemesterId = semesters.first.id;
            }
          }
          
          // Save the selected semester
          if (selectedSemesterId != null) {
            await PreferencesService.saveSelectedSemesterId(selectedSemesterId);
          }
        }
        
        // Update user info with semesters
        _userInfo = _userInfo!.copyWith(
          semesters: semesters,
          selectedSemesterId: selectedSemesterId,
        );
        
        debugPrint('✅ Semesters loaded: ${semesters.length} semesters, selected: $selectedSemesterId');
        debugPrint('📝 UserInfo now has ${_userInfo!.semesters.length} semesters');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load semesters: $e');
    }
  }
  
  /// Connect mentor to Stream Chat for selected student (non-blocking)
  void _connectMentorToStreamChat(String studentId) {
    // Run asynchronously to avoid blocking loadUserInfo
    Future.microtask(() async {
      try {
        // Connect if not connected yet
        if (!_streamChatService!.isUserConnected) {
          await _streamChatService!.connectUser(
            userId: _userInfo!.id,
            token: _userInfo!.getStreamToken!,
            userName: _userInfo!.name,
            userImage: _userInfo!.avatarUrl,
          );
        }
        
        // Watch the student's channel
        await _streamChatService!.getOrCreateChannel(
          channelId: studentId,
          channelType: 'messaging',
          members: [_userInfo!.id, studentId],
          extraData: {
            'name': 'Chat with ${getSelectedStudent()?.name ?? 'Student'}',
            'studentId': studentId,
            'mentorId': _userInfo!.id,
          },
        );
      } catch (e) {
        debugPrint('❌ Error connecting mentor to Stream Chat: $e');
      }
    });
  }

  /// Select a student (for mentors)
  Future<void> selectStudent(String studentId) async {
    if (_userInfo?.isMentor == true) {
      final previousStudentId = _selectedStudentId;
      _selectedStudentId = studentId;
      
      // Persist the selection
      await PreferencesService.saveSelectedStudentId(studentId);
      
      // Refresh student data to get latest GPA and other info
      await refreshUserInfo();
      
      // Handle Stream Chat presence switching immediately
      if (_streamChatService != null) {
        // Connect if not connected yet (first time selecting student)
        if (!_streamChatService!.isUserConnected) {
          try {
            await _streamChatService!.connectUser(
              userId: _userInfo!.id,
              token: _userInfo!.getStreamToken!,
              userName: _userInfo!.name,
              userImage: _userInfo!.avatarUrl,
            );
          } catch (e) {
            debugPrint('❌ [PRESENCE] Error connecting mentor: $e');
            notifyListeners();
            return;
          }
        }
        
        // Handle channel watching for the selected student
        try {
          // If switching from previous student, stop watching their channel first
          if (previousStudentId != null && previousStudentId != studentId) {
            try {
              final client = _streamChatService!.client;
              final previousChannel = client.channel('messaging', id: previousStudentId);
              await previousChannel.stopWatching();
            } catch (e) {
              debugPrint('⚠️ Could not stop watching previous channel: $e');
            }
          }
          
          // Start watching new student's channel
          await _streamChatService!.getOrCreateChannel(
            channelId: studentId,
            channelType: 'messaging',
            members: [_userInfo!.id, studentId],
            extraData: {
              'name': 'Chat with ${getSelectedStudent()?.name ?? 'Student'}',
              'studentId': studentId,
              'mentorId': _userInfo!.id,
            },
          );
        } catch (e) {
          debugPrint('❌ Error managing presence: $e');
        }
      }
      
      notifyListeners();
    }
  }
  
  /// Get currently selected student
  Student? getSelectedStudent() {
    if (_selectedStudentId == null || _userInfo?.students == null) {
      return null;
    }
    
    try {
      return _userInfo!.students.firstWhere(
        (student) => student.id == _selectedStudentId,
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Select a semester and update on backend
  Future<void> selectSemester(String semesterId) async {
    if (_userInfo != null) {
      _userInfo = _userInfo!.copyWith(selectedSemesterId: semesterId);
      debugPrint('Selected semester: $semesterId');
      
      // Persist the selection
      await PreferencesService.saveSelectedSemesterId(semesterId);
      
      notifyListeners();
      
      // Notify dependent features to refresh their data
      debugPrint('📢 Semester changed - dependent features should refresh');
      
      // TODO: Call API to persist semester selection if needed
      // await _apiService?.selectSemester(semesterId);
    }
  }
  
  /// Get currently selected semester
  Semester? getSelectedSemester() {
    final currentSemesters = semesters; // Use the getter
    final currentSelectedId = selectedSemesterId; // Use the getter that includes preferences
    
    debugPrint('🔍 getSelectedSemester: selectedId=$currentSelectedId, semestersCount=${currentSemesters.length}');
    
    if (currentSelectedId == null || currentSemesters.isEmpty) {
      debugPrint('🔍 getSelectedSemester: returning null (missing data)');
      return null;
    }
    
    try {
      final result = currentSemesters.firstWhere(
        (semester) => semester.id == currentSelectedId,
      );
      debugPrint('🔍 getSelectedSemester: found semester ${result.name}');
      return result;
    } catch (e) {
      debugPrint('🔍 getSelectedSemester: semester not found in list');
      return null;
    }
  }
  
}