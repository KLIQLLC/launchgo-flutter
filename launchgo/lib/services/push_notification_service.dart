import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'api_service_retrofit.dart';
import 'notifications_api_service.dart';
import 'pending_navigation_service.dart';
import 'auth_service.dart';
import 'package:go_router/go_router.dart';
import 'notification_navigation_service.dart';
import 'android_notification_display_service.dart';
import 'notification_parser.dart';
import 'video_call/video_call_push_handler.dart';

/// Service for handling FCM token lifecycle and device registration
class PushNotificationService extends ChangeNotifier {
  static PushNotificationService? _instance;
  static PushNotificationService get instance => _instance ??= PushNotificationService._();
  
  PushNotificationService._();
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  bool _isInitialized = false;
  NotificationsApiService? _notificationsService;
  GoRouter? _router;
  
  // Add auth service for semester switching
  AuthService? _authService;
  
  // Callback for when FCM token becomes available
  VoidCallback? _onTokenAvailableCallback;
  
  /// Log to file for debugging
  Future<void> _logToFile(String message) async {
    try {
      // Get the app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/debug_logs.txt');
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString('[$timestamp] $message\n', mode: FileMode.append);
      debugPrint('✅ Logged to file: ${file.path}');
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }
  
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;
  
  /// Set notifications service for updating badge count
  void setNotificationsService(NotificationsApiService notificationsService) {
    _notificationsService = notificationsService;
  }
  
  /// Set router for direct navigation
  void setRouter(GoRouter router) {
    _router = router;
    debugPrint('🔔 PushNotificationService: Router set for direct navigation');
  }
  
  /// Set auth service for semester switching
  void setAuthService(AuthService authService) {
    _authService = authService;
    // Initialize the notification navigation service
    if (_router != null) {
      NotificationNavigationService.instance.initialize(_router!, authService);
    }
    debugPrint('🔔 PushNotificationService: AuthService set for semester switching');
  }
  
  /// Set callback to be called when FCM token becomes available
  void setTokenAvailableCallback(VoidCallback callback) {
    _onTokenAvailableCallback = callback;
    // If token is already available, call the callback immediately
    if (_fcmToken != null) {
      Future.microtask(() => callback());
    }
  }
  
  /// Initialize FCM for basic functionality (without requesting permissions)
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('🔔 PushNotificationService already initialized, skipping...');
      return;
    }
    
    debugPrint('🔔 Initializing PushNotificationService...');
    
    try {
      // Setup message handlers without requesting permissions
      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Add global message listener for debugging
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('🔔 [GLOBAL] Foreground message: ${message.notification?.title}');
        debugPrint('🔔 [GLOBAL] Message data: ${message.data}');
      });
      
      // Handle message when app is opened from notification tap
      debugPrint('🔔 Setting up onMessageOpenedApp listener...');
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 [LISTENER] onMessageOpenedApp triggered!');
        _handleMessageOpenedApp(message);
      });
      
      // Handle initial message if app was opened from notification
      debugPrint('🔔 Checking for initial message...');
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 [INITIAL] App opened from notification (terminated state)');
        debugPrint('🔔 [INITIAL] Message data: ${initialMessage.data}');
        debugPrint('🔔 [INITIAL] Screen value: ${initialMessage.data['screen']}');
        // Store navigation - will be processed when router is ready
        _storeNavigationFromMessage(initialMessage);
      } else {
        debugPrint('🔔 No initial message found');
      }
      
      _isInitialized = true;
      notifyListeners();
      
      debugPrint('✅ PushNotificationService initialized successfully (no permissions requested yet)');
      _logToFile('PUSH_SERVICE_INITIALIZED: Message handlers ready, awaiting permissions');
    } catch (e) {
      debugPrint('❌ Error initializing PushNotificationService: $e');
      rethrow;
    }
  }
  

  /// Request notification permissions and setup FCM token
  Future<bool> requestPermissionsAndSetupToken() async {
    debugPrint('🔔 Requesting notification permissions...');
    
    try {
      // Initialize notification display service (Android only)
      if (Platform.isAndroid) {
        await AndroidNotificationDisplayService.instance.initialize();
      }
      
      // Request notification permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      debugPrint('🔔 Notification permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Wait for APNS token on iOS before getting FCM token
        debugPrint('🔔 Waiting for APNS token...');
        await _waitForApnsToken();
        
        // Get FCM token
        _fcmToken = await _messaging.getToken();
        debugPrint('🔔 FCM Token retrieved: $_fcmToken');
        
        // Call callback if set (for backend registration)
        if (_onTokenAvailableCallback != null) {
          debugPrint('🔔 Calling token available callback...');
          Future.microtask(() => _onTokenAvailableCallback!());
        }
        
        // Listen to token refresh
        _messaging.onTokenRefresh.listen((token) {
          _fcmToken = token;
          debugPrint('🔔 FCM Token refreshed: $token');
          notifyListeners();
          
          // Call callback for token refresh too
          if (_onTokenAvailableCallback != null) {
            Future.microtask(() => _onTokenAvailableCallback!());
          }
        });
        
        debugPrint('✅ Push notifications fully enabled with FCM token');
        debugPrint('🔔 FCM Token: $_fcmToken');
        _logToFile('PUSH_NOTIFICATIONS_ENABLED: FCM Token received, ready for notifications');
        
        notifyListeners();
        return true;
      } else {
        debugPrint('❌ Notification permission denied: ${settings.authorizationStatus}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permissions: $e');
      return false;
    }
  }
  
  /// Register device with backend using FCM token
  Future<void> registerDevice(ApiServiceRetrofit apiService) async {
    try {
      if (_fcmToken == null) {
        debugPrint('⚠️ No FCM token available for registration');
        return;
      }
      
      debugPrint('📱 Registering device with backend...');
      await apiService.registerFCMToken(_fcmToken!);
      debugPrint('✅ Device registered successfully with backend');
    } catch (e) {
      debugPrint('❌ Failed to register device with backend: $e');
      rethrow;
    }
  }
  
  /// Unregister device from backend
  Future<void> unregisterDevice(ApiServiceRetrofit apiService) async {
    try {
      if (_fcmToken == null) {
        debugPrint('⚠️ No FCM token available for unregistration');
        return;
      }
      
      debugPrint('🗑️ Unregistering device from backend...');
      await apiService.deleteFCMToken(_fcmToken!);
      debugPrint('✅ Device unregistered successfully from backend');
    } catch (e) {
      debugPrint('❌ Failed to unregister device from backend: $e');
      rethrow;
    }
  }
  
  /// Wait for APNS token to be available on iOS
  Future<void> _waitForApnsToken() async {
    try {
      final apnsToken = await _messaging.getAPNSToken();
      debugPrint('APNS token: $apnsToken');
    } catch (e) {
      debugPrint('Error getting APNS token: $e');
    }
  }
  
  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    // 🛑 BREAKPOINT: Set breakpoint here to inspect message data
    debugPrint('🔔 Foreground message received: ${message.notification?.title}');
    debugPrint('🔔 Message data: ${message.data}');
    debugPrint('🔔 Message body: ${message.notification?.body}');
    
    // Show the notification even when app is in foreground
    // For Stream Chat data-only notifications, show them manually
    if (NotificationParser.isStreamChatMessage(message.data)) {
      final chatData = NotificationParser.parseStreamChatData(message.data);
      AndroidNotificationDisplayService.instance.showStreamChatNotification(
        title: chatData.title,
        body: chatData.body,
        channelId: chatData.channelId,
        senderId: chatData.senderId,
      );
    } else {
      debugPrint('🔔 Non-Stream Chat foreground notification');
    }
    
    // Update notification badge count when foreground notification received
    if (_notificationsService != null) {
      Future.microtask(() => _notificationsService!.fetchNotifications());
    }
  }
  
  /// Handle message when app is opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    // 🛑 BREAKPOINT: Set breakpoint here to inspect notification tap data
    final logMessage = '''
============================================
Message opened app: ${message.notification?.title}
Message data: ${message.data}
Data keys: ${message.data.keys.toList()}
Screen value: ${message.data['screen']}
============================================''';
    
    debugPrint('🔔 $logMessage');
    _logToFile('NOTIFICATION_OPENED: $logMessage');
    
    // Parse and store navigation
    _storeNavigationFromMessage(message);
  }
  
  /// Parse message and execute direct navigation
  void _storeNavigationFromMessage(RemoteMessage message) {
    final data = message.data;

    // Handle video call notifications first (highest priority)
    if (VideoCallPushHandler.isVideoCallNotification(data)) {
      debugPrint('📞 Video call notification detected in push');
      VideoCallPushHandler.instance.handleVideoCallPush(data);
      return;
    }

    // First try to handle via NotificationNavigationService for structured notifications
    if (data.containsKey('eventType')) {
      final eventType = data['eventType'] as String;
      debugPrint('🔔 Using NotificationNavigationService for eventType: $eventType');
      
      // Use the centralized navigation service for all eventType notifications
      NotificationNavigationService.instance.handleNotification(
        eventType: eventType,
        data: data,
      );
      
      // Return early since navigation is handled by the service
      return;
    }
    
    // Handle Stream Chat notifications
    if (_isStreamChatNotification(data)) {
      debugPrint('🔔 Using NotificationNavigationService for chat notification');
      
      // Use the specialized navigation service for chat handling
      NotificationNavigationService.instance.handleChatNotification(
        receiverId: data['receiver_id'],
        channelId: data['channel_id'] ?? data['channel_cid'],
        channelType: data['channel_type'],
      );
      
      // Return early since navigation is handled by the service
      return;
    }
    
    // Fallback to legacy handling for backward compatibility
    String? targetRoute;
    Map<String, dynamic>? extra;
    
    if (data.containsKey('screen')) {
      final screen = data['screen'] as String;
      targetRoute = _getRouteFromScreen(screen);
      
      // Special handling for assignments with course_id
      if (screen.toLowerCase() == 'assignments' && data.containsKey('course_id')) {
        targetRoute = '/course/${data['course_id']}/assignments';
      }
    } else if (data.containsKey('route')) {
      targetRoute = data['route'] as String;
      if (data.containsKey('extra')) {
        extra = data['extra'] as Map<String, dynamic>;
      }
    }
    
    if (targetRoute != null) {
      if (_router != null) {
        debugPrint('🔔 Executing direct navigation to: $targetRoute');
        try {
          if (extra != null && extra.isNotEmpty) {
            _router!.go(targetRoute, extra: extra);
          } else {
            _router!.go(targetRoute);
          }
          debugPrint('🔔 Direct navigation executed successfully');
        } catch (e) {
          debugPrint('❌ Direct navigation failed: $e');
          // Fallback to pending service
          debugPrint('🔔 Falling back to pending navigation service');
          PendingNavigationService.instance.setPendingNavigation(targetRoute, extra: extra);
        }
      } else {
        debugPrint('🔔 Router not available, using pending navigation service');
        PendingNavigationService.instance.setPendingNavigation(targetRoute, extra: extra);
      }
    } else {
      debugPrint('🔔 No navigation target found in notification data');
    }
  }
  
  /// Get route from screen name
  String _getRouteFromScreen(String screen) {
    switch (screen.toLowerCase()) {
      case 'chat':
        return '/chat';
      case 'schedule':
        return '/schedule';
      case 'courses':
        return '/courses';
      case 'documents':
        return '/documents';
      case 'recaps':
        return '/recaps';
      case 'notifications':
        return '/notifications';
      case 'settings':
        return '/settings';
      case 'assignments':
        return '/courses'; // Default to courses, will be overridden if course_id is present
      default:
        debugPrint('🔔 Unknown screen: $screen, defaulting to /schedule');
        return '/schedule';
    }
  }
  
  /// Check if this is a Stream Chat notification
  bool _isStreamChatNotification(Map<String, dynamic> data) {
    return data.containsKey('channel_id') || 
           data.containsKey('channel_type') ||
           data.containsKey('channel_cid');
  }
  
  // iOS notification handler removed - Firebase handles everything now
  
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 🛑 BREAKPOINT: Set breakpoint here to inspect background notifications
  debugPrint('🔔 Background message received: ${message.notification?.title}');
  debugPrint('🔔 Background message data: ${message.data}');
  debugPrint('🔔 Background message body: ${message.notification?.body}');

  // Handle video call notifications
  // On iOS: VoIP push triggers CallKit automatically via StreamVideoPKDelegateManager
  // On Android: We need to manually show the incoming call UI when app is terminated
  if (VideoCallPushHandler.isVideoCallNotification(message.data)) {
    debugPrint('📞 Background video call notification detected');

    // On Android, we need to manually show the incoming call notification
    // because Stream Video SDK is not initialized in the background isolate
    if (Platform.isAndroid) {
      debugPrint('📞 Android: Showing incoming call notification manually');
      await _showAndroidIncomingCallNotification(message.data);
    } else {
      debugPrint('📞 iOS: CallKit will handle via VoIP push');
    }
    return;
  }

  // Handle background message
  // This runs when app is terminated or in background

  // For Stream Chat data-only notifications, we need to show them manually
  if (NotificationParser.isStreamChatMessage(message.data)) {
    final chatData = NotificationParser.parseStreamChatData(message.data);
    await AndroidNotificationDisplayService.instance.showStreamChatNotification(
      title: chatData.title,
      body: chatData.body,
      channelId: chatData.channelId,
      senderId: chatData.senderId,
    );
  } else if (message.notification != null) {
    // Android automatically shows notifications when app is in background/terminated
    // The system notification will appear in the notification tray
    debugPrint('🔔 Background notification will be shown by system');
  } else {
    debugPrint('🔔 Data-only notification received, no automatic display');
  }
}

/// Show incoming call notification on Android when app is terminated
/// Uses flutter_callkit_incoming to display full-screen incoming call UI
@pragma('vm:entry-point')
Future<void> _showAndroidIncomingCallNotification(Map<String, dynamic> data) async {
  debugPrint('📞 [Android Background] Showing incoming call notification');
  debugPrint('📞 [Android Background] Data: $data');

  // Extract call ID from push data
  // Stream Video sends call_cid in format "type:callId" (e.g., "default:abc123")
  debugPrint('📞 [Android Background] Raw push data keys: ${data.keys.toList()}');
  debugPrint('📞 [Android Background] call_cid from push: ${data['call_cid']}');
  debugPrint('📞 [Android Background] call_id from push: ${data['call_id']}');
  debugPrint('📞 [Android Background] id from push: ${data['id']}');

  String? callId;
  final callCid = data['call_cid'] as String?;
  if (callCid != null && callCid.contains(':')) {
    callId = callCid.split(':').last;
    debugPrint('📞 [Android Background] Extracted callId from call_cid: $callId');
  }
  callId ??= data['call_id'] as String? ?? data['id'] as String?;

  if (callId == null) {
    debugPrint('❌ [Android Background] No call ID found in push data');
    return;
  }

  // Extract caller name
  final callerName = data['caller_name'] as String? ??
      data['created_by_display_name'] as String? ??
      data['sender_name'] as String? ??
      'Mentor';

  debugPrint('📞 [Android Background] FINAL Call ID to use: $callId, Caller: $callerName');
  debugPrint('📞 [Android Background] Storing in extra - call_cid: ${callCid ?? 'default:$callId'}, call_id: $callId');

  // Generate a unique UUID for this call notification
  final uuid = const Uuid().v4();

  // Configure the incoming call notification
  final params = CallKitParams(
    id: uuid,
    nameCaller: callerName,
    appName: 'launchgo',
    type: 0, // 0 = video call, 1 = audio call
    textAccept: 'Accept',
    textDecline: 'Decline',
    duration: 30000, // Ring for 30 seconds
    extra: <String, dynamic>{
      'call_cid': callCid ?? 'default:$callId',
      'call_id': callId,
    },
    android: const AndroidParams(
      isCustomNotification: true,
      isShowLogo: false,
      ringtonePath: 'system_ringtone_default',
      backgroundColor: '#0955fa',
      actionColor: '#4CAF50',
      isShowFullLockedScreen: true,
      isShowCallID: false,
    ),
  );

  debugPrint('📞 [Android Background] Calling FlutterCallkitIncoming.showCallkitIncoming');
  await FlutterCallkitIncoming.showCallkitIncoming(params);
  debugPrint('✅ [Android Background] Incoming call notification shown');
}