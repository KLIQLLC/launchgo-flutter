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
    debugPrint('📞 VideoCallPushHandler initialized');
  }

  /// Check if this is a video call notification
  static bool isVideoCallNotification(Map<String, dynamic> data) {
    // Stream Video sends these fields in call notifications
    return data.containsKey('call_cid') ||
        data.containsKey('stream_video') ||
        data['type'] == 'call.ring' ||
        data['type'] == 'call.notification';
  }

  /// Handle video call push when app was terminated
  Future<void> handleVideoCallPush(Map<String, dynamic> data) async {
    debugPrint('📞 [VideoCallPushHandler] Handling video call push');
    debugPrint('📞 [VideoCallPushHandler] Data: $data');

    final callId = _extractCallId(data);
    final callerName = _extractCallerName(data);

    if (callId == null) {
      debugPrint('❌ [VideoCallPushHandler] No call ID found in push data');
      return;
    }

    debugPrint('📞 [VideoCallPushHandler] Call ID: $callId, Caller: $callerName');

    // Ensure auth is restored before proceeding
    await _waitForAuth();

    // Initialize video service if needed
    if (_authService?.userInfo != null && _videoService != null) {
      if (!_videoService!.isInitialized) {
        debugPrint('📞 [VideoCallPushHandler] Initializing video service...');
        await _videoService!.initialize(_authService!.userInfo!);
      }
    }

    // Navigate to incoming call screen
    if (_router != null) {
      debugPrint('📞 [VideoCallPushHandler] Navigating to incoming-call screen');
      _router!.pushNamed(
        'incoming-call',
        pathParameters: {'callId': callId},
        queryParameters: {'callerName': callerName ?? 'Mentor'},
      );
    } else {
      debugPrint('❌ [VideoCallPushHandler] Router not available');
    }
  }

  /// Extract call ID from push data
  /// Stream Video sends call_cid in format "type:callId" (e.g., "default:abc123")
  String? _extractCallId(Map<String, dynamic> data) {
    // Try call_cid first (Stream Video format)
    final callCid = data['call_cid'] as String?;
    if (callCid != null && callCid.contains(':')) {
      return callCid.split(':').last;
    }

    // Try direct call_id
    final callId = data['call_id'] as String?;
    if (callId != null) return callId;

    // Try id field
    return data['id'] as String?;
  }

  /// Extract caller name from push data
  String? _extractCallerName(Map<String, dynamic> data) {
    // Try various fields that might contain caller name
    return data['caller_name'] as String? ??
        data['created_by_display_name'] as String? ??
        data['sender_name'] as String?;
  }

  /// Wait for auth to be ready (up to 5 seconds)
  Future<void> _waitForAuth() async {
    debugPrint('📞 [VideoCallPushHandler] Waiting for auth...');
    for (int i = 0; i < 50; i++) {
      if (_authService?.userInfo != null) {
        debugPrint('📞 [VideoCallPushHandler] Auth ready');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    debugPrint('⚠️ [VideoCallPushHandler] Auth wait timeout');
  }
}
