import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service_retrofit.dart';
import 'notifications_api_service.dart';

/// Service for handling FCM token lifecycle and device registration
class PushNotificationService extends ChangeNotifier {
  static PushNotificationService? _instance;
  static PushNotificationService get instance => _instance ??= PushNotificationService._();
  
  PushNotificationService._();
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  bool _isInitialized = false;
  NotificationsApiService? _notificationsService;
  static const MethodChannel _channel = MethodChannel('push_notification_channel');
  
  // Callback for when FCM token becomes available
  VoidCallback? _onTokenAvailableCallback;
  
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;
  
  /// Set notifications service for updating badge count
  void setNotificationsService(NotificationsApiService notificationsService) {
    _notificationsService = notificationsService;
  }
  
  /// Set callback to be called when FCM token becomes available
  void setTokenAvailableCallback(VoidCallback callback) {
    _onTokenAvailableCallback = callback;
    // If token is already available, call the callback immediately
    if (_fcmToken != null) {
      Future.microtask(() => callback());
    }
  }
  
  /// Initialize FCM for basic functionality (token retrieval, permissions)
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('🔔 PushNotificationService already initialized, skipping...');
      return;
    }
    
    debugPrint('🔔 Initializing PushNotificationService...');
    
    try {
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
        
        // Handle background messages
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        
        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        
        // Set up method channel to receive notifications from native iOS
        _channel.setMethodCallHandler((MethodCall call) async {
          if (call.method == 'onForegroundMessage') {
            if (_notificationsService != null) {
              Future.microtask(() => _notificationsService!.fetchNotifications());
            }
          }
        });
        
        // Handle message when app is opened from notification tap
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
        
        // Handle initial message if app was opened from notification
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
        
        _isInitialized = true;
        notifyListeners();
        
        debugPrint('✅ PushNotificationService initialized successfully');
        debugPrint('🔔 FCM Token: $_fcmToken');
      } else {
        debugPrint('❌ Notification permission denied: ${settings.authorizationStatus}');
      }
    } catch (e) {
      debugPrint('❌ Error initializing PushNotificationService: $e');
      rethrow;
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
      // On iOS, we need to wait for APNS token before getting FCM token
      int attempts = 0;
      const maxAttempts = 10;
      const delay = Duration(milliseconds: 500);
      
      while (attempts < maxAttempts) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          debugPrint('🔔 APNS token received: ${apnsToken.substring(0, 20)}...');
          return;
        }
        
        if (attempts % 3 == 0) debugPrint('🔔 APNS token not available yet, waiting... (attempt ${attempts + 1}/$maxAttempts)');
        await Future.delayed(delay);
        attempts++;
      }
      
      debugPrint('⚠️ APNS token not received after $maxAttempts attempts');
    } catch (e) {
      debugPrint('❌ Error waiting for APNS token: $e');
    }
  }
  
  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 Foreground message received: ${message.notification?.title}');
    debugPrint('🔔 Message data: ${message.data}');
    debugPrint('🔔 Message body: ${message.notification?.body}');
    
    // Show the notification even when app is in foreground
    // Note: For production, you might want to show a custom in-app notification instead
    debugPrint('🔔 Showing notification in foreground');
    
    // Update notification badge count when foreground notification received
    if (_notificationsService != null) {
      Future.microtask(() => _notificationsService!.fetchNotifications());
    }
  }
  
  /// Handle message when app is opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔔 Message opened app: ${message.notification?.title}');
    
    // Navigate to specific screen based on message data
    _handleNotificationTap(message);
  }
  
  
  /// Handle notification tap navigation
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    
    debugPrint('🔔 Notification data: $data');
    
    // Handle Stream Chat notifications
    if (data.containsKey('channel_id') || data.containsKey('channel_type')) {
      debugPrint('🔔 Navigate to chat channel: ${data['channel_id']}');
      // Navigate to chat screen - this will be handled by the router
      _navigateToChat(data);
      return;
    }
    
    // Navigate based on notification data
    if (data.containsKey('screen')) {
      final screen = data['screen'];
      debugPrint('🔔 Navigate to screen: $screen');
      
      switch (screen) {
        case 'chat':
          _navigateToChat(data);
          break;
        case 'schedule':
          _navigateToSchedule();
          break;
        case 'assignments':
          _navigateToSchedule(); // Assignments are on schedule screen
          break;
        default:
          debugPrint('🔔 Unknown screen: $screen');
      }
    }
  }
  
  /// Navigate to chat screen
  void _navigateToChat(Map<String, dynamic> data) {
    debugPrint('🔔 Navigating to chat with data: $data');
    // This would be implemented with your router
    // Example: GoRouter.of(context).go('/chat', extra: data);
  }
  
  /// Navigate to schedule screen
  void _navigateToSchedule() {
    debugPrint('🔔 Navigating to schedule');
    // This would be implemented with your router
    // Example: GoRouter.of(context).go('/schedule');
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.notification?.title}');
  debugPrint('🔔 Background message data: ${message.data}');
  debugPrint('🔔 Background message body: ${message.notification?.body}');
  
  // Handle background message
  // This runs when app is terminated or in background
  
  // Android automatically shows notifications when app is in background/terminated
  // The system notification will appear in the notification tray
  debugPrint('🔔 Background notification will be shown by system');
  
  // You can update local storage, sync data, etc.
  // But avoid heavy operations here
}