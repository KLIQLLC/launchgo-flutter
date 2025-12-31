// services/push_notification_service.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service_retrofit.dart';
import 'notifications_api_service.dart';
import 'pending_navigation_service.dart';
import 'auth_service.dart';
import 'package:go_router/go_router.dart';
import 'notification_navigation_service.dart';
import 'android_notification_display_service.dart';
import 'notification_parser.dart';
import 'video_call/video_call_push_handler.dart';
import 'video_call/video_call_native_bridge.dart';

/// Check if Stream Chat message is call-related (system message about call)
/// Stream sends regular FCM pushes for call log messages, but we don't want to show them
/// because VoIP push already handles the call UI
bool _isCallRelatedStreamMessage(Map<String, dynamic> data) {
  // Check message body/title for call-related text
  final body = (data['body'] as String? ?? '').toLowerCase();
  final title = (data['title'] as String? ?? '').toLowerCase();
  
  final isCallText = body.contains('call started') ||
      body.contains('call ended') ||
      body.contains('call missed') ||
      body.contains('call declined') ||
      title.contains('call started') ||
      title.contains('call ended') ||
      title.contains('call missed') ||
      title.contains('call declined');

  // Also check stream.* fields if available
  final streamType = data['stream.type'] as String?;
  final streamChannelType = data['stream.channel_type'] as String?;
  
  // Stream may put call-related info in stream fields
  final isStreamCallRelated = streamType != null && streamType.contains('call') ||
      streamChannelType != null && streamChannelType.contains('call');

  return isCallText || isStreamCallRelated;
}

/// Service for handling FCM token lifecycle and device registration
class PushNotificationService extends ChangeNotifier {
  static PushNotificationService? _instance;
  static PushNotificationService get instance => _instance ??= PushNotificationService._();
  
  PushNotificationService._();
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  Future<bool>? _permissionsInFlight;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _lastNotifiedToken;
  bool _isInitialized = false;
  NotificationsApiService? _notificationsService;
  GoRouter? _router;
  
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
  Future<bool> requestPermissionsAndSetupToken({String caller = 'unknown'}) async {
    // Single-flight: many places call this during startup/login; only one should actually
    // hit iOS permission APIs and token wiring.
    final inFlight = _permissionsInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _requestPermissionsAndSetupTokenInternal(caller: caller);
    _permissionsInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_permissionsInFlight, future)) {
        _permissionsInFlight = null;
      }
    }
  }

  Future<bool> _requestPermissionsAndSetupTokenInternal({required String caller}) async {
    debugPrint('🔔 Requesting notification permissions... caller=$caller');

    try {
      // Initialize notification display service (Android only)
      if (Platform.isAndroid) {
        await AndroidNotificationDisplayService.instance.initialize();
      }

      // Avoid re-requesting permission if we already have it.
      final before = await _messaging.getNotificationSettings();
      var status = before.authorizationStatus;
      debugPrint('🔔 Notification permission status (before request): $status');

      if (status == AuthorizationStatus.notDetermined) {
        // Request notification permissions
        final settings = await _messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        status = settings.authorizationStatus;
        debugPrint('🔔 Notification permission status (after request): $status');
      }

      if (status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional) {
        
        // iOS requires APNs configured in Firebase; we do not use the APNs token directly here.
        
        // Get FCM token
        final token = await _messaging.getToken();
        _fcmToken = token;
        debugPrint('🔔 FCM Token retrieved: $_fcmToken');
        
        // Call callback if set (for backend registration)
        if (_onTokenAvailableCallback != null &&
            _fcmToken != null &&
            _fcmToken!.isNotEmpty &&
            _lastNotifiedToken != _fcmToken) {
          debugPrint('🔔 Calling token available callback...');
          _lastNotifiedToken = _fcmToken;
          Future.microtask(() => _onTokenAvailableCallback!());
        }
        
        // Listen to token refresh (only once)
        _tokenRefreshSub ??= _messaging.onTokenRefresh.listen((token) async {
          _fcmToken = token;
          debugPrint('🔔 FCM Token refreshed: $token');
          notifyListeners();

          if (_onTokenAvailableCallback != null &&
              token.isNotEmpty &&
              _lastNotifiedToken != token) {
            _lastNotifiedToken = token;
            Future.microtask(() => _onTokenAvailableCallback!());
          }
        });
        
        debugPrint('✅ Push notifications fully enabled with FCM token');
        debugPrint('🔔 FCM Token: $_fcmToken');
        _logToFile('PUSH_NOTIFICATIONS_ENABLED: FCM Token received, ready for notifications');
        
        notifyListeners();
        return true;
      } else {
        // NotDetermined can happen if multiple callers race while the system dialog is up.
        if (status == AuthorizationStatus.notDetermined) {
          debugPrint('⚠️ Notification permission still not determined (dialog may be pending)');
        } else {
          debugPrint('❌ Notification permission denied: $status');
        }
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
  
  // (removed) _waitForApnsToken(): we don't need to block on APNs token in app code

  
  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // 🛑 EARLY LOGGING - See raw push data before any processing
    debugPrint('');
    debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] ========== PUSH RECEIVED (FOREGROUND) ==========');
    debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] TIMESTAMP: ${DateTime.now().toIso8601String()}');
    debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] MESSAGE ID: ${message.messageId}');
    debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] DATA PAYLOAD: ${message.data}');
    debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] DATA KEYS: ${message.data.keys.toList()}');
    debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] TYPE: ${message.data['type']}');
    debugPrint('');

    // Check if this is a video call notification
    if (VideoCallPushHandler.isVideoCallNotification(message.data)) {
      final notificationType = message.data['type'] as String?;
      debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] VIDEO CALL NOTIFICATION DETECTED');
      debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] Notification type: $notificationType');

      if (notificationType == 'call.missed' || notificationType == 'call.ended') {
        // Call was cancelled/missed - ensure CallKit is ended
        // This is a backup in case WebSocket notification is delayed
        debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] Call missed/ended (type=$notificationType)');
        debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] Ending any active CallKit notifications');
        if (Platform.isAndroid) {
          FlutterCallkitIncoming.endAllCalls().catchError((e) {
            debugPrint('[VC] ❌ [PushNotificationService:_handleForegroundMessage] Error ending CallKit: $e');
          });
        }
      } else if (notificationType == 'call.ring') {
        debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] call.ring - App is in foreground');
        debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] WebSocket will handle incoming call');
        debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] NOT showing CallKit notification (in-app UI will show instead)');
      } else {
        debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] Unknown type: $notificationType');
      }
      debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] ========== END FOREGROUND VIDEO CALL ==========');
      return;
    }

    // Show the notification even when app is in foreground
    // For Stream Chat data-only notifications, show them manually
    if (NotificationParser.isStreamChatMessage(message.data)) {
      // Check if this is a call-related message (system message about call)
      // Stream sends regular FCM pushes for call log messages, but we don't want to show them
      // because VoIP push already handles the call UI
      if (_isCallRelatedStreamMessage(message.data)) {
        debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] Call-related Stream Chat message detected - skipping notification display');
        debugPrint('[VC] 📞 [PushNotificationService:_handleForegroundMessage] Only VoIP push will show call UI');
        return;
      }

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

    debugPrint('🔔 ========== END FOREGROUND MESSAGE ==========');

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
/// NOTE: This runs in a separate isolate where StreamVideo.instance is NOT available.
/// For Android terminated state, we must manually show CallKit notification.
/// When user accepts, the app launches and consumeAndAcceptActiveCall() handles joining.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 🛑 EARLY LOGGING - See raw push data before any processing
  debugPrint('');
  debugPrint('[VC] 📞 [BackgroundHandler] ========== PUSH RECEIVED (BACKGROUND) ==========');
  debugPrint('[VC] 📞 [BackgroundHandler] TIMESTAMP: ${DateTime.now().toIso8601String()}');
  debugPrint('[VC] 📞 [BackgroundHandler] MESSAGE ID: ${message.messageId}');
  debugPrint('[VC] 📞 [BackgroundHandler] DATA PAYLOAD: ${message.data}');
  debugPrint('[VC] 📞 [BackgroundHandler] DATA KEYS: ${message.data.keys.toList()}');
  debugPrint('[VC] 📞 [BackgroundHandler] TYPE: ${message.data['type']}');
  debugPrint('');

  // Handle video call notifications
  // On iOS: VoIP push triggers CallKit automatically via StreamVideoPKDelegateManager in AppDelegate
  // On Android (terminated): We must manually show CallKit because StreamVideo isn't initialized here
  // On Android (background): SDK should handle via handleRingingFlowNotifications in foreground listener
  if (VideoCallPushHandler.isVideoCallNotification(message.data)) {
    debugPrint('[VC] 📞 [BackgroundHandler] ========== VIDEO CALL NOTIFICATION ==========');
    debugPrint('[VC] 📞 [BackgroundHandler] Video call notification detected');
    debugPrint('[VC] 📞 [BackgroundHandler] Message data: ${message.data}');

    final notificationType = message.data['type'] as String?;
    debugPrint('[VC] 📞 [BackgroundHandler] Notification type: $notificationType');

    // On Android, we need to handle both showing and ending CallKit notifications
    // because Stream Video SDK is not initialized in the background isolate.
    if (Platform.isAndroid) {
      if (notificationType == 'call.ring') {
        debugPrint('[VC] 📞 [BackgroundHandler] Android: call.ring - Showing incoming call notification');
        await _showAndroidIncomingCallNotification(message.data);
      } else if (notificationType == 'call.missed' || notificationType == 'call.ended') {
        debugPrint('[VC] 📞 [BackgroundHandler] Android: $notificationType - Ending CallKit notification');
        await _endAndroidCallNotification();
      } else {
        debugPrint('[VC] 📞 [BackgroundHandler] Android: Unhandled type: $notificationType');
      }
    } else {
      debugPrint('[VC] 📞 [BackgroundHandler] iOS: VoIP push handled natively');
    }
    debugPrint('[VC] 📞 [BackgroundHandler] ========== END VIDEO CALL NOTIFICATION ==========');
    return;
  }

  // Handle background message
  // This runs when app is terminated or in background

  // For Stream Chat data-only notifications, we need to show them manually
  if (NotificationParser.isStreamChatMessage(message.data)) {
    // Check if this is a call-related message (system message about call)
    // Stream sends regular FCM pushes for call log messages, but we don't want to show them
    // because VoIP push already handles the call UI
    if (_isCallRelatedStreamMessage(message.data)) {
      debugPrint('[VC] 📞 [BackgroundHandler] Call-related Stream Chat message detected - skipping notification display');
      debugPrint('[VC] 📞 [BackgroundHandler] Only VoIP push will show call UI');
      return;
    }

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

/// End incoming call notification on Android when call is cancelled
/// This is called when mentor cancels the call (call.miss or call.ended)
@pragma('vm:entry-point')
Future<void> _endAndroidCallNotification() async {
  debugPrint('[VC] 📞 [Android Background] Ending incoming call notification (caller cancelled)');
  try {
    await FlutterCallkitIncoming.endAllCalls();
    debugPrint('[VC] ✅ [Android Background] CallKit notification ended successfully');
  } catch (e) {
    debugPrint('[VC] ❌ [Android Background] Error ending CallKit notification: $e');
  }
}

/// Show incoming call notification on Android when app is terminated
/// Uses flutter_callkit_incoming to display full-screen incoming call UI
@pragma('vm:entry-point')
Future<void> _showAndroidIncomingCallNotification(Map<String, dynamic> data) async {
  debugPrint('[VC] 📞 [Android Background] Showing incoming call notification');
  debugPrint('[VC] 📞 [Android Background] Data: $data');

  // End any existing active calls before showing new one
  // This prevents the issue where a previous call blocks the new notification
  // Always try to end calls unconditionally - activeCalls() can return stale data
  try {
    debugPrint('[VC] 📞 [Android Background] Ending any existing calls unconditionally');
    await FlutterCallkitIncoming.endAllCalls();
    // Small delay to ensure previous calls are fully ended
    await Future.delayed(const Duration(milliseconds: 300));
  } catch (e) {
    debugPrint('[VC] ⚠️ [Android Background] Error ending previous calls (continuing anyway): $e');
    // Even if endAllCalls fails, we'll try to show the new notification
    // Add extra delay when there's an error
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Extract call ID from push data
  // Stream Video sends call_cid in format "type:callId" (e.g., "default:abc123")
  debugPrint('[VC] 📞 [Android Background] Raw push data keys: ${data.keys.toList()}');
  debugPrint('[VC] 📞 [Android Background] call_cid from push: ${data['call_cid']}');
  debugPrint('[VC] 📞 [Android Background] call_id from push: ${data['call_id']}');
  debugPrint('[VC] 📞 [Android Background] id from push: ${data['id']}');

  String? callId;
  final callCid = data['call_cid'] as String?;
  if (callCid != null && callCid.contains(':')) {
    callId = callCid.split(':').last;
    debugPrint('[VC] 📞 [Android Background] Extracted callId from call_cid: $callId');
  }
  callId ??= data['call_id'] as String? ?? data['id'] as String?;

  if (callId == null) {
    debugPrint('[VC] ❌ [Android Background] No call ID found in push data');
    return;
  }

  // Extract caller name
  final callerName = data['caller_name'] as String? ??
      data['created_by_display_name'] as String? ??
      data['sender_name'] as String? ??
      'Mentor';

  debugPrint('[VC] 📞 [Android Background] FINAL Call ID to use: $callId, Caller: $callerName');
  debugPrint('[VC] 📞 [Android Background] Storing in extra - call_cid: ${callCid ?? 'default:$callId'}, call_id: $callId');

  // Use call_id as notification ID so we can track it
  // This allows SharedPreferences listener to detect decline by call_id
  debugPrint('[VC] 📞 [Android Background] Using call_id as notification ID: $callId');

  // Configure the incoming call notification
  final params = CallKitParams(
    id: callId,  // Use actual call_id, not random UUID
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

  debugPrint('[VC] 📞 [Android Background] Calling FlutterCallkitIncoming.showCallkitIncoming');

  // Try to show the incoming call notification with retry logic
  int retryCount = 0;
  const maxRetries = 2;

  while (retryCount <= maxRetries) {
    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
      debugPrint('[VC] ✅ [Android Background] Incoming call notification shown successfully');

      // Save pending call to SharedPreferences
      // This is the KEY for detecting decline in terminated state!
      // When app starts, it checks if pending call is NOT in activeCalls → declined
      debugPrint('[VC] 📞 [Android Background] Saving pending call to SharedPreferences...');
      try {
        await VideoCallNativeBridge.savePendingCall(
          callId: callId,
          callCid: callCid,
        );
        debugPrint('[VC] 📞 [Android Background] Pending call saved successfully');
      } catch (e) {
        debugPrint('[VC] ⚠️ [Android Background] Error saving pending call: $e');
      }

      // Also try to schedule WorkManager (may not work in isolate)
      try {
        await VideoCallNativeBridge.scheduleCallMonitor(
          callId: callId,
          callCid: callCid,
        );
        debugPrint('[VC] 📞 [Android Background] WorkManager scheduled successfully');
      } catch (e) {
        debugPrint('[VC] ⚠️ [Android Background] Could not schedule WorkManager (expected in isolate): $e');
      }

      return;
    } catch (e) {
      retryCount++;
      debugPrint('[VC] ❌ [Android Background] Error showing notification (attempt $retryCount/$maxRetries): $e');

      if (retryCount <= maxRetries) {
        // Wait and try again
        await Future.delayed(const Duration(milliseconds: 500));
        // Try to clear any stale state before retry
        try {
          await FlutterCallkitIncoming.endAllCalls();
        } catch (_) {
          // Ignore error on retry cleanup
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  debugPrint('[VC] ❌ [Android Background] Failed to show notification after $maxRetries retries');
}