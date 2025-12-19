import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../auth_service.dart';
import 'stream_video_service.dart';

/// Dedicated handler for video call push notifications
/// Handles navigation when app wakes from terminated state via VoIP push
class VideoCallPushHandler {
  static final VideoCallPushHandler instance = VideoCallPushHandler._();
  VideoCallPushHandler._();

  GoRouter? _router;
  AuthService? _authService;
  StreamVideoService? _videoService;

  /// Initialize with dependencies
  void initialize(
    GoRouter router,
    AuthService authService,
    StreamVideoService videoService,
  ) {
    _router = router;
    _authService = authService;
    _videoService = videoService;
    debugPrint('[VC] 📞 VideoCallPushHandler initialized');
  }

  /// Check if this is a video call notification
  static bool isVideoCallNotification(Map<String, dynamic> data) {
    // Stream Video sends these fields in call notifications
    // Types:
    // - call.ring: incoming call (show CallKit)
    // - call.missed: call was missed/rejected (end CallKit)
    // - call.ended: call ended (end CallKit)
    // - call.notification: general call notification
    return data.containsKey('call_cid') ||
        data.containsKey('stream_video') ||
        data['type'] == 'call.ring' ||
        data['type'] == 'call.missed' ||
        data['type'] == 'call.ended' ||
        data['type'] == 'call.notification';
  }

  /// Handle video call push when app was terminated
  Future<void> handleVideoCallPush(Map<String, dynamic> data) async {
    debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] >> ENTRY');
    debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] Push data: $data');
    debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] Auth available: ${_authService != null}');
    debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] Video service available: ${_videoService != null}');
    debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] Router available: ${_router != null}');

    // Ensure auth is restored before proceeding
    debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] Waiting for auth to be ready...');
    await _waitForAuth();
    debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] Auth wait complete');

    // Initialize video service if needed
    if (_authService?.userInfo != null && _videoService != null) {
      debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] Auth and video service available');
      debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] Video service initialized: ${_videoService!.isInitialized}');

      if (!_videoService!.isInitialized) {
        debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] Video service NOT initialized, initializing now...');
        await _videoService!.initialize(_authService!.userInfo!);
        debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] Video service initialization complete');
      }

      // Pass the notification to Stream Video SDK's ringing flow handler
      // This will trigger the proper observers and CallKit integration
      // The SDK handles:
      // 1. Displaying CallKit/incoming call UI
      // 2. Managing call state
      // 3. Triggering observeCoreRingingEvents callbacks when user accepts/rejects
      debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] Passing notification to Stream Video SDK handleRingingFlowNotifications...');
      final handled = await _videoService!.handleRingingFlowNotifications(data);
      debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] Stream Video SDK handled: $handled');

      if (handled) {
        debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] << EXIT: SDK handled successfully');
        debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] observeCoreRingingEvents callbacks will trigger navigation');
        // The SDK will trigger observeCoreRingingEvents callbacks
        // which will handle navigation via the callback we set up in main.dart
        return;
      } else {
        debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] SDK did NOT handle notification');
        debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] This may happen if the call has already ended or was handled elsewhere');
        // Don't fall back to manual navigation - let the SDK listeners handle it
        // The WebSocket-based incomingCall stream should still work
        return;
      }
    } else {
      debugPrint('[VC] ⚠️ [VideoCallPushHandler:handleVideoCallPush] Auth or video service not available');
      debugPrint('[VC] ⚠️ [VideoCallPushHandler:handleVideoCallPush] Cannot process video call push without auth');
    }

    // NOTE: We no longer use fallback navigation here.
    // The SDK's observeCoreRingingEvents and incomingCall stream in main.dart
    // will handle navigation when the call arrives via WebSocket.
    // Manual navigation can cause duplicate screens and conflicts with SDK state.
    debugPrint('[VC] 📞 [VideoCallPushHandler:handleVideoCallPush] << EXIT: No fallback navigation - relying on SDK streams');
  }

  /// Wait for auth to be ready (up to 5 seconds)
  Future<void> _waitForAuth() async {
    debugPrint('[VC] 📞 [VideoCallPushHandler] Waiting for auth...');
    for (int i = 0; i < 50; i++) {
      if (_authService?.userInfo != null) {
        debugPrint('[VC] 📞 [VideoCallPushHandler] Auth ready');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    debugPrint('[VC] ⚠️ [VideoCallPushHandler] Auth wait timeout');
  }
}
