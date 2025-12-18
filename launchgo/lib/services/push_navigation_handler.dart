// services/push_navigation_handler.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Handles push notification navigation with proper timing
class PushNavigationHandler {
  static PushNavigationHandler? _instance;
  static PushNavigationHandler get instance =>
      _instance ??= PushNavigationHandler._();

  PushNavigationHandler._();

  GoRouter? _router;
  RemoteMessage? _pendingMessage;
  Timer? _navigationTimer;

  void setRouter(GoRouter router) {
    _router = router;
    debugPrint('🚀 PushNavigationHandler: Router set');

    // Check if we have a pending navigation
    if (_pendingMessage != null) {
      debugPrint('🚀 PushNavigationHandler: Processing pending navigation');
      Future.delayed(const Duration(milliseconds: 500), () {
        _processPendingNavigation();
      });
    }
  }

  /// Queue a navigation from push notification
  void queueNavigation(RemoteMessage message) {
    debugPrint('🚀 ============================================');
    debugPrint('🚀 PushNavigationHandler: Queueing navigation');
    debugPrint('🚀 Message data: ${message.data}');

    _pendingMessage = message;

    // Cancel any existing timer
    _navigationTimer?.cancel();

    // If router is ready, process immediately
    if (_router != null) {
      // Use a timer to ensure we're not in the middle of a navigation
      _navigationTimer = Timer(const Duration(milliseconds: 1000), () {
        _processPendingNavigation();
      });
    } else {
      debugPrint(
        '🚀 Router not ready, navigation will be processed when router is set',
      );
    }

    debugPrint('🚀 ============================================');
  }

  void _processPendingNavigation() {
    if (_pendingMessage == null || _router == null) {
      debugPrint('🚀 No pending navigation or router not ready');
      return;
    }

    final data = _pendingMessage!.data;
    debugPrint('🚀 Processing navigation with data: $data');

    try {
      // Determine navigation target
      if (data.containsKey('screen')) {
        final screen = data['screen'] as String;
        _navigateToScreen(screen, data);
      } else if (data.containsKey('route')) {
        final route = data['route'] as String;
        _navigateToRoute(route, data);
      } else if (_isStreamChatNotification(data)) {
        _navigateToChat(data);
      }

      // Clear pending message after successful navigation
      _pendingMessage = null;
    } catch (e) {
      debugPrint('❌ Error processing navigation: $e');
      // Retry after delay
      _navigationTimer = Timer(const Duration(seconds: 1), () {
        _processPendingNavigation();
      });
    }
  }

  bool _isStreamChatNotification(Map<String, dynamic> data) {
    return data.containsKey('channel_id') ||
        data.containsKey('channel_type') ||
        data.containsKey('channel_cid');
  }

  void _navigateToScreen(String screen, Map<String, dynamic> data) {
    debugPrint('🚀 Navigating to screen: $screen');

    String targetRoute;
    switch (screen.toLowerCase()) {
      case 'chat':
        targetRoute = '/chat';
        break;
      case 'schedule':
        targetRoute = '/schedule';
        break;
      case 'courses':
        targetRoute = '/courses';
        break;
      case 'documents':
        targetRoute = '/documents';
        break;
      case 'recaps':
        targetRoute = '/recaps';
        break;
      case 'notifications':
        targetRoute = '/notifications';
        break;
      case 'settings':
        targetRoute = '/settings';
        break;
      case 'assignments':
        if (data.containsKey('course_id')) {
          targetRoute = '/course/${data['course_id']}/assignments';
        } else {
          targetRoute = '/courses';
        }
        break;
      default:
        debugPrint('🚀 Unknown screen: $screen, defaulting to /schedule');
        targetRoute = '/schedule';
    }

    debugPrint('🚀 Executing navigation to: $targetRoute');

    // Use Future.microtask to ensure we're not blocking the UI
    Future.microtask(() {
      try {
        _router!.go(targetRoute);
        debugPrint('🚀 Navigation completed to: $targetRoute');
      } catch (e) {
        debugPrint('❌ Navigation error: $e');
        // Fallback navigation
        Future.delayed(const Duration(milliseconds: 500), () {
          _router!.go('/schedule');
        });
      }
    });
  }

  void _navigateToRoute(String route, Map<String, dynamic> data) {
    debugPrint('🚀 Navigating to route: $route');
    final cleanRoute = route.startsWith('/') ? route : '/$route';

    Future.microtask(() {
      try {
        if (data.containsKey('extra')) {
          _router!.go(cleanRoute, extra: data['extra']);
        } else {
          _router!.go(cleanRoute);
        }
        debugPrint('🚀 Navigation completed to route: $cleanRoute');
      } catch (e) {
        debugPrint('❌ Route navigation error: $e');
        _router!.go('/schedule');
      }
    });
  }

  void _navigateToChat(Map<String, dynamic> data) {
    debugPrint('🚀 Navigating to chat');
    final channelId = data['channel_id'] ?? data['channel_cid'];

    Future.microtask(() {
      try {
        if (channelId != null) {
          _router!.go(
            '/chat',
            extra: {
              'channelId': channelId,
              'channelType': data['channel_type'] ?? 'messaging',
            },
          );
        } else {
          _router!.go('/chat');
        }
        debugPrint('🚀 Navigation completed to chat');
      } catch (e) {
        debugPrint('❌ Chat navigation error: $e');
        _router!.go('/chat');
      }
    });
  }

  void dispose() {
    _navigationTimer?.cancel();
    _pendingMessage = null;
  }
}
