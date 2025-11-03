import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'auth_service.dart';
import 'notification_navigation_service.dart';

/// Android-specific notification display service
/// 
/// This service handles manual notification display for Android only.
/// iOS notifications are handled automatically by the system and do not
/// require manual display logic.
/// 
/// Key Features:
/// - Creates notification channels for Android 8.0+
/// - Displays Stream Chat data-only notifications manually
/// - Handles notification tap navigation
/// - Platform detection prevents execution on iOS
class AndroidNotificationDisplayService {
  static AndroidNotificationDisplayService? _instance;
  static AndroidNotificationDisplayService get instance => _instance ??= AndroidNotificationDisplayService._();
  
  AndroidNotificationDisplayService._();
  
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  
  GoRouter? _router;
  AuthService? _authService;
  
  /// Set router for navigation handling
  void setRouter(GoRouter router) {
    _router = router;
    debugPrint('🔔 NotificationDisplayService: Router set for tap navigation');
  }
  
  /// Set auth service for student switching
  void setAuthService(AuthService authService) {
    _authService = authService;
    debugPrint('🔔 NotificationDisplayService: AuthService set for student switching');
  }
  
  /// Initialize the local notifications plugin
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Only initialize on Android (iOS doesn't need manual notification display)
      if (Platform.isAndroid) {
        const initializationSettingsAndroid = AndroidInitializationSettings('@drawable/ic_notification');
        const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
        
        await _localNotifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );
        
        // Create notification channels
        await _createNotificationChannels();
        
        debugPrint('✅ NotificationDisplayService initialized successfully');
      }
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Error initializing NotificationDisplayService: $e');
    }
  }
  
  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    debugPrint('🔔 Creating notification channels for Android...');
    
    // Create the default notification channel
    const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
      'default_notification_channel',
      'Default Notifications',
      description: 'Default notification channel for app notifications',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    
    // Create the chat notification channel
    const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      'chat_notifications',
      'Chat Messages',
      description: 'Notifications for new chat messages',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(defaultChannel);
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(chatChannel);
      
      debugPrint('✅ Notification channels created successfully');
    } catch (e) {
      debugPrint('❌ Error creating notification channels: $e');
    }
  }
  
  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    
    if (response.payload == null) {
      debugPrint('🔔 No payload data for notification tap');
      return;
    }
    
    try {
      // Parse the payload data
      final payloadData = jsonDecode(response.payload!);
      final notificationType = payloadData['type'] as String?;
      
      if (notificationType == 'chat') {
        _handleChatNotificationTap(payloadData);
      } else {
        debugPrint('🔔 Unknown notification type: $notificationType');
      }
    } catch (e) {
      debugPrint('❌ Error parsing notification payload: $e');
      debugPrint('Raw payload: ${response.payload}');
    }
  }
  
  /// Handle chat notification tap
  void _handleChatNotificationTap(Map<String, dynamic> data) {
    final channelId = data['channelId'] as String?;
    final senderId = data['senderId'] as String?;
    
    if (channelId == null) {
      debugPrint('❌ No channelId in chat notification payload');
      return;
    }
    
    debugPrint('🔔 Handling chat notification tap - channelId: $channelId, senderId: $senderId');
    
    // Use the NotificationNavigationService for proper chat handling
    NotificationNavigationService.instance.handleChatNotification(
      receiverId: senderId,
      channelId: channelId,
      channelType: 'messaging',
    );
  }
  
  /// Show a Stream Chat notification
  Future<void> showStreamChatNotification({
    required String title,
    required String body,
    String? channelId,
    String? senderId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Only show on Android (iOS handles notifications automatically)
    if (!Platform.isAndroid) return;
    
    try {
      debugPrint('🔔 Showing Stream Chat notification: $title - $body');
      
      // Create structured payload for tap handling
      final payload = jsonEncode({
        'type': 'chat',
        'channelId': channelId,
        'senderId': senderId,
      });
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // Use timestamp as ID
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_notifications',
            'Chat Messages',
            channelDescription: 'Notifications for new chat messages',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
            icon: '@drawable/ic_notification',
          ),
        ),
        payload: payload,
      );
      
      debugPrint('✅ Stream Chat notification shown successfully');
    } catch (e) {
      debugPrint('❌ Error showing Stream Chat notification: $e');
    }
  }
  
  /// Show a general app notification
  Future<void> showGeneralNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Only show on Android (iOS handles notifications automatically)
    if (!Platform.isAndroid) return;
    
    try {
      debugPrint('🔔 Showing general notification: $title - $body');
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_notification_channel',
            'Default Notifications',
            channelDescription: 'Default notification channel for app notifications',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
            icon: '@drawable/ic_notification',
          ),
        ),
        payload: payload,
      );
      
      debugPrint('✅ General notification shown successfully');
    } catch (e) {
      debugPrint('❌ Error showing general notification: $e');
    }
  }
}