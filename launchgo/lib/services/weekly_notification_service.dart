import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/user_model.dart';
import 'permissions_service.dart';
import 'android_notification_display_service.dart';

/// Service for managing weekly recap notifications for mentors
/// 
/// This service schedules local notifications every Friday at 9 AM to remind
/// mentors to submit their weekly recaps. It leverages the existing notification
/// infrastructure and only targets mentors and case managers.
/// 
/// Key Features:
/// - Role-based notification scheduling (mentors only)
/// - Weekly recurring notifications (Fridays at 9 AM)
/// - Proper lifecycle management (schedule on login, cancel on logout)
/// - Platform-aware implementation (leverages existing AndroidNotificationDisplayService)
class WeeklyNotificationService {
  static WeeklyNotificationService? _instance;
  static WeeklyNotificationService get instance => _instance ??= WeeklyNotificationService._();
  
  WeeklyNotificationService._();
  
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static const int _weeklyNotificationId = 1001;
  bool _isInitialized = false;
  
  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    debugPrint('📅 Initializing WeeklyNotificationService...');
    
    try {
      // Initialize timezone database
      tz.initializeTimeZones();
      
      // Only initialize if not already initialized by AndroidNotificationDisplayService
      if (Platform.isAndroid) {
        // Leverage existing AndroidNotificationDisplayService initialization
        await AndroidNotificationDisplayService.instance.initialize();
        debugPrint('📅 Using existing AndroidNotificationDisplayService for notifications');
      } else {
        // iOS initialization
        const DarwinInitializationSettings initializationSettingsDarwin = 
            DarwinInitializationSettings(
              requestAlertPermission: true,
              requestBadgePermission: true,
              requestSoundPermission: true,
            );
        
        const InitializationSettings initializationSettings = InitializationSettings(
          iOS: initializationSettingsDarwin,
        );
        
        await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
        debugPrint('📅 iOS local notifications initialized');
      }
      
      _isInitialized = true;
      debugPrint('✅ WeeklyNotificationService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing WeeklyNotificationService: $e');
      rethrow;
    }
  }
  
  /// Schedule weekly recap notification for mentors (Fridays at 9 AM)
  Future<void> scheduleWeeklyRecapNotification(UserModel? userInfo) async {
    if (!_isInitialized) {
      debugPrint('⚠️ WeeklyNotificationService not initialized');
      return;
    }
    
    // Only schedule for mentors and case managers
    final permissions = PermissionsService(userInfo);
    if (!permissions.isMentor && !permissions.isCaseManager) {
      debugPrint('📅 User is not a mentor/case manager, skipping weekly notification setup');
      return;
    }
    
    try {
      // Cancel any existing weekly notification
      await _flutterLocalNotificationsPlugin.cancel(_weeklyNotificationId);
      
      // Calculate next Friday at 9 AM
      final now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime nextFridayAt9AM = _getNextFridayAt9AM(now);
      
      debugPrint('📅 Scheduling weekly recap notification for: $nextFridayAt9AM');
      
      // Create notification details
      const AndroidNotificationDetails androidPlatformChannelSpecifics = 
          AndroidNotificationDetails(
            'weekly_recap_channel',
            'Weekly Recap Reminders',
            channelDescription: 'Notifications to remind mentors to submit weekly recaps',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            icon: 'ic_notification', // Use existing notification icon
          );
      
      const DarwinNotificationDetails iosPlatformChannelSpecifics = 
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );
      
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );
      
      // Create payload data for navigation
      final payloadData = {
        'eventType': 'weekly-recap',
      };
      final payload = jsonEncode(payloadData);
      
      // Schedule the recurring notification
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        _weeklyNotificationId,
        'Weekly Recap Reminder',
        'Please make sure you submit your weekly recaps.',
        nextFridayAt9AM,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Repeat weekly
        payload: payload,
      );
      
      debugPrint('✅ Weekly recap notification scheduled successfully for Fridays at 9 AM');
      debugPrint('📅 Next notification: $nextFridayAt9AM');
      
    } catch (e) {
      debugPrint('❌ Failed to schedule weekly recap notification: $e');
    }
  }
  
  /// Cancel weekly recap notification
  Future<void> cancelWeeklyRecapNotification() async {
    if (!_isInitialized) return;
    
    try {
      await _flutterLocalNotificationsPlugin.cancel(_weeklyNotificationId);
      debugPrint('🗑️ Weekly recap notification cancelled');
    } catch (e) {
      debugPrint('❌ Failed to cancel weekly recap notification: $e');
    }
  }
  
  /// Calculate the next Friday at 9 AM
  tz.TZDateTime _getNextFridayAt9AM(tz.TZDateTime now) {
    // Friday is weekday 5 (Monday = 1, Sunday = 7)
    const int fridayWeekday = 5;
    const int targetHour = 9;
    const int targetMinute = 0;
    
    // Start with today at 9 AM
    tz.TZDateTime candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      targetHour,
      targetMinute,
    );
    
    // If today is Friday and it's before 9 AM, schedule for today
    if (now.weekday == fridayWeekday && now.isBefore(candidate)) {
      return candidate;
    }
    
    // Otherwise, find the next Friday
    int daysUntilFriday = fridayWeekday - now.weekday;
    if (daysUntilFriday <= 0) {
      daysUntilFriday += 7; // Next week's Friday
    }
    
    return candidate.add(Duration(days: daysUntilFriday));
  }
  
  /// Get pending notifications for debugging
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized) return [];
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }
  
  /// Request notification permissions (especially for iOS)
  Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (Platform.isAndroid) {
      // On Android, permissions are handled by AndroidNotificationDisplayService
      return true;
    } else {
      // On iOS, request permissions directly
      final result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      
      return result ?? false;
    }
  }
  
  /// Check if weekly notification is currently scheduled
  Future<bool> isWeeklyNotificationScheduled() async {
    if (!_isInitialized) return false;
    
    final pendingNotifications = await getPendingNotifications();
    return pendingNotifications.any((notification) => notification.id == _weeklyNotificationId);
  }
}