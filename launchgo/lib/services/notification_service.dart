import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Service for handling Firebase Cloud Messaging push notifications
class NotificationService extends ChangeNotifier {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  
  NotificationService._();
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  bool _isInitialized = false;
  
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;
  
  /// Initialize push notifications
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    debugPrint('🔔 Initializing notification service...');
    
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
        debugPrint('🔔 FCM Token: $_fcmToken');
        
        // Listen to token refresh
        _messaging.onTokenRefresh.listen((token) {
          _fcmToken = token;
          debugPrint('🔔 FCM Token refreshed: $token');
          _sendTokenToServer(token);
          notifyListeners();
        });
        
        // Send initial token to server
        if (_fcmToken != null) {
          await _sendTokenToServer(_fcmToken!);
        }
        
        // Handle background messages
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        
        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        
        // Handle message when app is opened from notification tap
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
        
        // Handle initial message if app was opened from notification
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
        
        _isInitialized = true;
        notifyListeners();
        
        debugPrint('✅ Notification service initialized successfully');
        debugPrint('🔔 FCM Token: $_fcmToken');
      } else {
        debugPrint('❌ Notification permission denied: ${settings.authorizationStatus}');
        debugPrint('🔔 Alert: ${settings.alert}');
        debugPrint('🔔 Badge: ${settings.badge}');
        debugPrint('🔔 Sound: ${settings.sound}');
      }
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
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
        
        debugPrint('🔔 APNS token not available yet, waiting... (attempt ${attempts + 1}/$maxAttempts)');
        await Future.delayed(delay);
        attempts++;
      }
      
      debugPrint('⚠️ APNS token not received after $maxAttempts attempts');
    } catch (e) {
      debugPrint('❌ Error waiting for APNS token: $e');
    }
  }
  
  /// Send FCM token to backend server
  Future<void> _sendTokenToServer(String token) async {
    try {
      // You can implement this to send the token to your backend
      // Example:
      // final apiService = ApiServiceRetrofit(authService: AuthService.instance);
      // await apiService.updateFCMToken(token);
      
      debugPrint('📤 FCM token would be sent to server: $token');
    } catch (e) {
      debugPrint('❌ Error sending FCM token to server: $e');
    }
  }
  
  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 Foreground message received: ${message.notification?.title}');
    
    // You can show a custom in-app notification here
    // Or update app state based on the message
    
    if (message.notification != null) {
      _showLocalNotification(message);
    }
  }
  
  /// Handle message when app is opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔔 Message opened app: ${message.notification?.title}');
    
    // Navigate to specific screen based on message data
    _handleNotificationTap(message);
  }
  
  /// Show local notification for foreground messages
  void _showLocalNotification(RemoteMessage message) {
    // This is handled by the native platform notification system
    // The iOS and Android configurations already show notifications in foreground
    debugPrint('🔔 Showing notification: ${message.notification!.title}');
  }
  
  /// Handle notification tap navigation
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    
    // Navigate based on notification data
    if (data.containsKey('screen')) {
      final screen = data['screen'];
      debugPrint('🔔 Navigate to screen: $screen');
      
      // Example navigation logic:
      // switch (screen) {
      //   case 'chat':
      //     // Navigate to chat screen
      //     break;
      //   case 'schedule':
      //     // Navigate to schedule screen
      //     break;
      //   case 'assignments':
      //     // Navigate to assignments screen
      //     break;
      // }
    }
  }
  
  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic $topic: $e');
    }
  }
  
  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic $topic: $e');
    }
  }
  
  /// Update user's notification preferences
  Future<void> updateNotificationPreferences({
    required bool enableAssignmentReminders,
    required bool enableEventReminders,
    required bool enableChatNotifications,
    required bool enableGeneralUpdates,
  }) async {
    try {
      // Subscribe/unsubscribe from topics based on preferences
      if (enableAssignmentReminders) {
        await subscribeToTopic('assignment_reminders');
      } else {
        await unsubscribeFromTopic('assignment_reminders');
      }
      
      if (enableEventReminders) {
        await subscribeToTopic('event_reminders');
      } else {
        await unsubscribeFromTopic('event_reminders');
      }
      
      if (enableChatNotifications) {
        await subscribeToTopic('chat_notifications');
      } else {
        await unsubscribeFromTopic('chat_notifications');
      }
      
      if (enableGeneralUpdates) {
        await subscribeToTopic('general_updates');
      } else {
        await unsubscribeFromTopic('general_updates');
      }
      
      debugPrint('✅ Notification preferences updated');
    } catch (e) {
      debugPrint('❌ Error updating notification preferences: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.notification?.title}');
  
  // Handle background message
  // This runs when app is terminated or in background
  
  // You can update local storage, show notifications, etc.
  // But avoid heavy operations here
}