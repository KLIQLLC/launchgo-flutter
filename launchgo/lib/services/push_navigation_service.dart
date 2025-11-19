import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../router/app_router.dart';

/// Service for handling navigation from push notifications
class PushNavigationService {
  static PushNavigationService? _instance;
  static PushNavigationService get instance => _instance ??= PushNavigationService._();
  
  PushNavigationService._();
  
  GoRouter? _router;
  AppRouter? _appRouter;
  
  /// Initialize the service with the router
  void initialize(GoRouter router) {
    _router = router;
    debugPrint('🧭 PushNavigationService initialized');
  }
  
  /// Set the AppRouter instance for advanced navigation
  void setAppRouter(AppRouter appRouter) {
    _appRouter = appRouter;
    debugPrint('🧭 AppRouter set in PushNavigationService');
  }
  
  /// Handle navigation from a push notification
  void handleNotificationNavigation(RemoteMessage message) {
    debugPrint('🧭 ============================================');
    debugPrint('🧭 handleNotificationNavigation called');
    debugPrint('🧭 Router initialized: ${_router != null}');
    
    if (_router == null) {
      debugPrint('❌ PushNavigationService: Router not initialized');
      return;
    }
    
    final data = message.data;
    debugPrint('🧭 Notification data: $data');
    debugPrint('🧭 Current route: $currentLocation');
    
    // Handle different notification types
    if (_isStreamChatNotification(data)) {
      debugPrint('🧭 Detected Stream Chat notification');
      _navigateToChat(data);
    } else if (data.containsKey('screen')) {
      debugPrint('🧭 Detected screen navigation: ${data['screen']}');
      _navigateToScreen(data['screen'], data);
    } else if (data.containsKey('route')) {
      debugPrint('🧭 Detected route navigation: ${data['route']}');
      _navigateToRoute(data['route'], data);
    } else {
      debugPrint('🧭 No navigation action for notification');
    }
    debugPrint('🧭 ============================================');
  }
  
  /// Check if this is a Stream Chat notification
  bool _isStreamChatNotification(Map<String, dynamic> data) {
    return data.containsKey('channel_id') || 
           data.containsKey('channel_type') ||
           data.containsKey('channel_cid');
  }
  
  /// Navigate to chat screen with optional channel data
  void _navigateToChat(Map<String, dynamic> data) {
    try {
      final channelId = data['channel_id'] ?? data['channel_cid'];
      debugPrint('🧭 Navigating to chat, channel: $channelId');
      
      // Navigate to chat screen
      // If we have channel data, we could pass it as extra
      if (channelId != null) {
        _router!.go('/chat', extra: {
          'channelId': channelId,
          'channelType': data['channel_type'] ?? 'messaging',
        });
      } else {
        _router!.go('/chat');
      }
    } catch (e) {
      debugPrint('❌ Error navigating to chat: $e');
      // Fallback to default chat screen
      _router!.go('/chat');
    }
  }
  
  /// Navigate to a specific screen based on screen name
  void _navigateToScreen(String screen, Map<String, dynamic> data) {
    debugPrint('🧭 Navigating to screen: $screen');
    debugPrint('🧭 Current location before navigation: $currentLocation');
    
    // Try to get context from navigator key for more reliable navigation
    final context = _appRouter?.navigatorKey.currentContext;
    
    switch (screen.toLowerCase()) {
      case 'chat':
        _navigateToChat(data);
        break;
      
      case 'schedule':
        debugPrint('🧭 Going to /schedule');
        if (context != null) {
          debugPrint('🧭 Using context.go for navigation');
          context.go('/schedule');
        } else {
          debugPrint('🧭 Using router.go for navigation');
          _router!.go('/schedule');
        }
        debugPrint('🧭 Navigation to /schedule completed');
        break;
      
      case 'courses':
        debugPrint('🧭 Going to /courses');
        if (context != null) {
          debugPrint('🧭 Using context.go for navigation');
          context.go('/courses');
        } else {
          debugPrint('🧭 Using router.go for navigation');
          _router!.go('/courses');
        }
        debugPrint('🧭 Navigation to /courses completed');
        break;
      
      case 'documents':
        debugPrint('🧭 Going to /documents');
        if (context != null) {
          debugPrint('🧭 Using context.go for navigation');
          context.go('/documents');
        } else {
          debugPrint('🧭 Using router.go for navigation');
          _router!.go('/documents');
        }
        debugPrint('🧭 Navigation to /documents completed');
        break;
      
      case 'recaps':
        // Check if user has access to recaps
        _router!.go('/recaps');
        break;
      
      case 'assignments':
        // Assignments are typically under courses
        if (data.containsKey('course_id')) {
          _router!.go('/course/${data['course_id']}/assignments');
        } else {
          _router!.go('/courses');
        }
        break;
      
      case 'notifications':
        _router!.go('/notifications');
        break;
      
      case 'settings':
        _router!.go('/settings');
        break;
      
      default:
        debugPrint('🧭 Unknown screen: $screen, navigating to schedule');
        _router!.go('/schedule');
    }
  }
  
  /// Navigate to a specific route path
  void _navigateToRoute(String route, Map<String, dynamic> data) {
    debugPrint('🧭 Navigating to route: $route');
    
    try {
      // Clean up the route if needed
      final cleanRoute = route.startsWith('/') ? route : '/$route';
      
      // Check if we have extra data to pass
      if (data.containsKey('extra')) {
        _router!.go(cleanRoute, extra: data['extra']);
      } else {
        _router!.go(cleanRoute);
      }
    } catch (e) {
      debugPrint('❌ Error navigating to route $route: $e');
      // Fallback to schedule
      _router!.go('/schedule');
    }
  }
  
  /// Navigate to a deep link URL
  void navigateToDeepLink(String deepLink) {
    if (_router == null) {
      debugPrint('❌ PushNavigationService: Router not initialized');
      return;
    }
    
    debugPrint('🧭 Navigating to deep link: $deepLink');
    
    try {
      // Parse the deep link and navigate
      final uri = Uri.parse(deepLink);
      _router!.go(uri.path, extra: uri.queryParameters);
    } catch (e) {
      debugPrint('❌ Error navigating to deep link: $e');
      _router!.go('/schedule');
    }
  }
  
  /// Navigate to notification detail
  void navigateToNotificationDetail(String notificationId) {
    debugPrint('🧭 Navigating to notification detail: $notificationId');
    _router?.go('/notifications', extra: {'notificationId': notificationId});
  }
  
  /// Check if we can navigate (router is initialized)
  bool get canNavigate => _router != null;
  
  /// Get current route location
  String? get currentLocation {
    try {
      // Use the router configuration to get current location
      return _router?.routerDelegate.currentConfiguration.uri.toString();
    } catch (e) {
      return null;
    }
  }
}