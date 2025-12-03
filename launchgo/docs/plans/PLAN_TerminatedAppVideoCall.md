# Implementation Plan: Join Video Call When App is Terminated

## Overview
Enable students to receive and join video calls when the app is completely terminated/closed.

## Current State Analysis

### What's Already Implemented
1. **VoIP Push Packages Installed:**
   - `stream_video_push_notification: ^0.8.2`
   - `flutter_callkit_incoming: 2.5.2`

2. **iOS AppDelegate:** Registers for VoIP push via `StreamVideoPKDelegateManager.shared.registerForPushNotifications()`

3. **StreamVideoService:**
   - Initialized with `StreamVideoPushNotificationManager`
   - `acceptIncomingCall(callId)` already supports fetching call by ID when `_incomingCall` is null

4. **Auth Restoration:** User session restored from stored token on app launch

5. **Incoming Call Screen:** Accepts `callId` as path parameter

### What's Missing
1. **CallKit Event Handling:** No Dart-side listener for CallKit accept/decline events
2. **Video Call Push Detection:** `push_notification_service.dart` doesn't detect video call pushes
3. **Navigation from Push:** No routing to incoming-call screen when app wakes from VoIP push
4. **Initialization Timing:** StreamVideoService may not be ready when push arrives

---

## Implementation Steps

### Step 1: Add CallKit Event Listener in Dart
**File:** `lib/services/video_call/stream_video_service.dart`

Add listener for `flutter_callkit_incoming` events:
```dart
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

// In initialize() method, add:
FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
  if (event == null) return;

  switch (event.event) {
    case Event.actionCallAccept:
      // User accepted from CallKit - join call
      final callId = event.body['id'];
      _handleCallKitAccept(callId);
      break;
    case Event.actionCallDecline:
      // User declined from CallKit
      final callId = event.body['id'];
      _handleCallKitDecline(callId);
      break;
    case Event.actionCallEnded:
      // Call ended
      break;
    default:
      break;
  }
});
```

### Step 2: Create Video Call Push Handler
**File:** `lib/services/video_call/video_call_push_handler.dart` (NEW)

Create dedicated handler for video call pushes:
```dart
class VideoCallPushHandler {
  static final instance = VideoCallPushHandler._();
  VideoCallPushHandler._();

  GoRouter? _router;
  AuthService? _authService;
  StreamVideoService? _videoService;

  void initialize(GoRouter router, AuthService authService, StreamVideoService videoService) {
    _router = router;
    _authService = authService;
    _videoService = videoService;
  }

  /// Check if this is a video call notification
  static bool isVideoCallNotification(Map<String, dynamic> data) {
    return data.containsKey('call_cid') ||
           data.containsKey('stream_video') ||
           data['type'] == 'call.ring';
  }

  /// Handle video call push when app was terminated
  Future<void> handleVideoCallPush(Map<String, dynamic> data) async {
    final callId = _extractCallId(data);
    final callerName = _extractCallerName(data);

    if (callId == null) return;

    // Ensure auth is restored
    await _waitForAuth();

    // Initialize video service if needed
    if (_authService?.userInfo != null) {
      await _videoService?.initialize(_authService!.userInfo!);
    }

    // Navigate to incoming call screen
    _router?.pushNamed(
      'incoming-call',
      pathParameters: {'callId': callId},
      queryParameters: {'callerName': callerName ?? 'Mentor'},
    );
  }

  String? _extractCallId(Map<String, dynamic> data) {
    // Stream Video sends call_cid in format "default:callId"
    final callCid = data['call_cid'] as String?;
    if (callCid != null && callCid.contains(':')) {
      return callCid.split(':').last;
    }
    return data['call_id'] as String?;
  }

  String? _extractCallerName(Map<String, dynamic> data) {
    return data['caller_name'] ?? data['created_by_display_name'];
  }

  Future<void> _waitForAuth() async {
    // Wait up to 5 seconds for auth to be ready
    for (int i = 0; i < 50; i++) {
      if (_authService?.userInfo != null) return;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}
```

### Step 3: Update Push Notification Service
**File:** `lib/services/push_notification_service.dart`

Add video call detection to `_storeNavigationFromMessage`:
```dart
// At the beginning of _storeNavigationFromMessage:
if (VideoCallPushHandler.isVideoCallNotification(data)) {
  debugPrint('📞 Video call notification detected');
  VideoCallPushHandler.instance.handleVideoCallPush(data);
  return;
}
```

Also update background handler:
```dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Check for video call notification first
  if (VideoCallPushHandler.isVideoCallNotification(message.data)) {
    debugPrint('📞 Background video call notification - CallKit will handle');
    // CallKit handles the native UI, Dart handles when user accepts
    return;
  }
  // ... rest of existing code
}
```

### Step 4: Update main.dart Initialization
**File:** `lib/main.dart`

Initialize VideoCallPushHandler after router is ready:
```dart
// After line 164 (NotificationNavigationService.instance.initialize)
VideoCallPushHandler.instance.initialize(
  _appRouter.router,
  _authService,
  _streamVideoService,
);
```

### Step 5: Handle CallKit Accept in StreamVideoService
**File:** `lib/services/video_call/stream_video_service.dart`

Add methods to handle CallKit events:
```dart
/// Handle CallKit accept action (user accepted from native UI)
Future<void> handleCallKitAccept(String callId) async {
  debugPrint('📞 CallKit accept for call: $callId');

  // If client isn't initialized yet, store the pending call
  if (_client == null) {
    _pendingCallId = callId;
    return;
  }

  // Accept and join the call
  final call = await acceptIncomingCall(callId: callId);
  if (call != null) {
    // Navigation will be handled by the listener in main.dart
    debugPrint('✅ Call accepted from CallKit: $callId');
  }
}

/// Handle CallKit decline action
Future<void> handleCallKitDecline(String callId) async {
  debugPrint('📞 CallKit decline for call: $callId');

  if (_client == null) return;

  // Create call object to reject
  final call = _client!.makeCall(
    callType: StreamCallType.defaultType(),
    id: callId,
  );
  await call.getOrCreate();
  await call.reject();

  debugPrint('✅ Call declined from CallKit: $callId');
}

// Add field for pending call when app wakes up
String? _pendingCallId;

// In initialize(), after client is connected:
if (_pendingCallId != null) {
  final pendingId = _pendingCallId;
  _pendingCallId = null;
  await handleCallKitAccept(pendingId!);
}
```

### Step 6: iOS Native Configuration
**File:** `ios/Runner/Info.plist`

Ensure VoIP background modes are enabled:
```xml
<key>UIBackgroundModes</key>
<array>
  <string>voip</string>
  <string>audio</string>
  <string>fetch</string>
  <string>remote-notification</string>
</array>
```

### Step 7: Update AppDelegate for Full CallKit Support
**File:** `ios/Runner/AppDelegate.swift`

The current implementation uses `StreamVideoPKDelegateManager` which should handle VoIP push registration. Verify it's properly configured to:
1. Receive VoIP pushes
2. Show CallKit UI
3. Pass events to Flutter via `flutter_callkit_incoming`

---

## Testing Checklist

### iOS Testing
- [ ] App terminated + VoIP push received → CallKit UI appears
- [ ] Accept from CallKit → App launches, call connects
- [ ] Decline from CallKit → Call rejected, app stays closed
- [ ] Accept from lock screen → Works correctly
- [ ] Multiple rapid calls → Only one CallKit UI at a time

### Android Testing
- [ ] App terminated + FCM push → Full-screen notification appears
- [ ] Accept from notification → App launches, call connects
- [ ] Decline from notification → Call rejected
- [ ] Accept from lock screen → Works correctly

### Edge Cases
- [ ] Token expired when call arrives → Should prompt re-auth
- [ ] Network offline → Graceful error handling
- [ ] Call already ended by caller → Show "call ended" message
- [ ] Rapid logout/login → Correct user's token used

---

## File Changes Summary

| File | Action | Description |
|------|--------|-------------|
| `lib/services/video_call/stream_video_service.dart` | MODIFY | Add CallKit event listener, handle accept/decline |
| `lib/services/video_call/video_call_push_handler.dart` | CREATE | Dedicated handler for video call pushes |
| `lib/services/push_notification_service.dart` | MODIFY | Detect and route video call notifications |
| `lib/main.dart` | MODIFY | Initialize VideoCallPushHandler |
| `ios/Runner/Info.plist` | VERIFY | Ensure VoIP background modes |

---

## Dependencies
- `flutter_callkit_incoming: 2.5.2` (already installed)
- `stream_video_push_notification: ^0.8.2` (already installed)

## Risks & Mitigations
1. **VoIP certificate not configured:** Stream Dashboard must have APNs VoIP certificate uploaded
2. **CallKit permission denied:** Show settings prompt to enable
3. **Race condition on app wake:** Use pending call queue + wait for auth

## Estimated Complexity
- **Medium-High** - Multiple moving parts (iOS native, Flutter, Stream SDK)
- Main complexity: Coordinating CallKit events with Flutter state
