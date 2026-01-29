// services/video_call/stream_video_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:launchgo/utils/call_debug_logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';
import '../../config/environment.dart';
import '../../models/user_model.dart';
import '../preferences_service.dart';
import '../secure_storage_service.dart';
import 'video_call_native_bridge.dart';
import 'voip_pushkit_service.dart';

/// Callback type for when a call is accepted via CallKit/push (call already joined)
typedef OnCallAcceptedCallback = void Function(Call call);

/// Service for managing Stream Video calls
/// Follows official GetStream Flutter patterns from:
/// https://getstream.io/video/sdk/flutter/tutorial/ringing/
class StreamVideoService extends ChangeNotifier {
  StreamVideo? _client;
  Call? _activeCall;
  String? _incomingCallId;
  String? _incomingCallerName;
  bool _isInitialized = false;
  bool _isInitializing = false; // Prevent concurrent initialization
  Completer<void>? _initializeCompleter; // Allows callers to await in-flight initialization

  StreamSubscription<Call?>? _incomingCallSubscription;
  CompositeSubscription? _ringingEventsSubscription;
  StreamSubscription<CoordinatorEvent>? _coordinatorEventsSubscription;
  OnCallAcceptedCallback? _onCallAcceptedCallback;

  /// iOS method channel for call validity timer
  static const _iosTimerChannel = MethodChannel('com.launchgo.app/call_validity');
  
  /// iOS method channel for native reject flow (store/clear Stream Video auth for CallKit decline while app is terminated)
  static const _iosStreamVideoAuthChannel = MethodChannel('com.launchgo.app/stream_video_auth');

  StreamVideo? get client => _client;
  Call? get activeCall => _activeCall;
  bool get hasActiveCall => _activeCall != null;
  String? get incomingCallId => _incomingCallId;
  String? get incomingCallerName => _incomingCallerName;
  bool get isInitialized => _isInitialized;

  /// Start iOS native timer for call cancellation detection
  void _startIOSTimer(String callCid) {
    if (!Platform.isIOS) return;
    debugPrint('[VC] 📞 [iOS] Starting call validity timer for: $callCid');
    _iosTimerChannel.invokeMethod('startTimer', {'cid': callCid}).catchError((e) {
      debugPrint('[VC] ⚠️ [iOS] Error starting timer: $e');
    });
  }

  /// Stop iOS native timer
  void _stopIOSTimer() {
    if (!Platform.isIOS) return;
    debugPrint('[VC] 📞 [iOS] Stopping call validity timer');
    _iosTimerChannel.invokeMethod('stopTimer').catchError((e) {
      debugPrint('[VC] ⚠️ [iOS] Error stopping timer: $e');
    });
  }

  /// Set callback for when call is accepted via CallKit/push (for navigation)
  void setOnCallAcceptedCallback(OnCallAcceptedCallback? callback) {
    _onCallAcceptedCallback = callback;
    debugPrint('[VC] 📞 [StreamVideoService:setOnCallAcceptedCallback] Callback set for call acceptance');
  }

  /// Initialize the video client
  Future<void> initialize(UserModel user) async {
    debugPrint('[VC] 📞 [StreamVideoService:initialize] >> ENTRY');
    debugPrint('[VC] 📞 [StreamVideoService:initialize] User ID: ${user.id}');
    debugPrint('[VC] 📞 [StreamVideoService:initialize] User role: ${user.role}');
    debugPrint('[VC] 📞 [StreamVideoService:initialize] Currently initialized: $_isInitialized');
    debugPrint('[VC] 📞 [StreamVideoService:initialize] Currently initializing: $_isInitializing');
    debugPrint('[VC] 📞 [StreamVideoService:initialize] Client exists: ${_client != null}');
    debugPrint('[VC] 📞 [StreamVideoService:initialize] Has token: ${user.callGetStreamToken != null}');

    if (_isInitialized && _client != null) {
      debugPrint('[VC] 📞 [StreamVideoService:initialize] << EXIT: Already initialized, skipping');
      return;
    }

    if (_isInitializing) {
      debugPrint('[VC] 📞 [StreamVideoService:initialize] Initialization already in progress, awaiting existing init...');
      final existing = _initializeCompleter?.future;
      if (existing != null) {
        return await existing;
      }
      // Fallback: should not happen, but avoid leaving callers hanging.
      return;
    }

    _isInitializing = true;
    _initializeCompleter = Completer<void>();

    try {
      final apiKey = EnvironmentConfig.streamVideoApiKey;
      final token = user.callGetStreamToken ?? '';

      if (token.isEmpty) {
        debugPrint('[VC] ❌ [StreamVideoService:initialize] << EXIT: No video token available');
        throw Exception('No Stream Video token available');
      }

      // Verify token not expired
      debugPrint('[VC] 📞 [StreamVideoService:initialize] Verifying token validity...');
      if (!_verifyToken(token)) {
        debugPrint('[VC] ❌ [StreamVideoService:initialize] << EXIT: Token expired');
        throw Exception('Stream Video token is expired or invalid');
      }
      debugPrint('[VC] 📞 [StreamVideoService:initialize] Token is valid');

      // Reset StreamVideo singleton if it was already initialized elsewhere.
      // This can happen if initialization raced or if previous state leaked across hot restarts / lifecycle.
      if (StreamVideo.isInitialized()) {
        debugPrint('[VC] 📞 [StreamVideoService:initialize] StreamVideo singleton already initialized -> resetting');
        await StreamVideo.reset();
        debugPrint('[VC] 📞 [StreamVideoService:initialize] StreamVideo singleton reset complete');
      }

      // Create client with push notification support
      debugPrint('[VC] 📞 [StreamVideoService:initialize] Creating new StreamVideo client instance...');
      _client = StreamVideo(
        apiKey,
        user: User.regular(
          userId: user.id,
          name: user.name,
          image: user.avatarUrl,
        ),
        userToken: token,
        options: const StreamVideoOptions(
          logPriority: Priority.verbose,
          keepConnectionsAliveWhenInBackground: true,
        ),
        pushNotificationManagerProvider: StreamVideoPushNotificationManager.create(
          iosPushProvider: const StreamVideoPushProvider.apn(
            name: 'voip_apns',
          ),
          androidPushProvider: const StreamVideoPushProvider.firebase(
            name: 'video_firebase',
          ),
        ),
      );

      // Cache Stream Video bootstrap user so CallKit accept can initialize/join without waiting for userInfo API.
      // Best-effort only; never fail init.
      try {
        await SecureStorageService.saveStreamVideoBootstrapUser(user);
      } catch (_) {}
      
      // iOS: Store Stream Video auth for native CallKit decline -> reject call API when Flutter isn't running.
      if (Platform.isIOS) {
        try {
          await _iosStreamVideoAuthChannel.invokeMethod('set', {
            'apiKey': apiKey,
            'token': token,
          });
        } catch (_) {
          // Best effort; do not fail init
        }
      }

      // Save credentials for native Android background access (call rejection)
      if (Platform.isAndroid) {
        debugPrint('[VC] 📞 [StreamVideoService:initialize] Saving credentials for native Android access...');
        await PreferencesService.saveStreamVideoCredentials(
          token: token,
          apiKey: apiKey,
          userId: user.id,
        );
        debugPrint('[VC] 📞 [StreamVideoService:initialize] Credentials saved to SharedPreferences');
      }

      // Connect to establish WebSocket
      debugPrint('[VC] 📞 [StreamVideoService:initialize] Connecting to Stream Video WebSocket...');
      // We want the device to be registered for pushes while logged in on ALL platforms.
      // Logout is responsible for removing devices and disabling PushKit on iOS.
      final shouldRegisterPushDevice = true;
      await CallDebugLogger.log(
        '[VIDEO_PUSH] StreamVideo.connect(registerPushDevice=$shouldRegisterPushDevice platform=${Platform.operatingSystem})',
      );
      await _client!.connect(registerPushDevice: shouldRegisterPushDevice);
      debugPrint('[VC] 📞 [StreamVideoService:initialize] WebSocket connected successfully');

      // Set up listeners based on user role
      if (user.role == UserRole.student) {
        debugPrint('[VC] 📞 [StreamVideoService:initialize] User is STUDENT, setting up incoming call listeners...');
        _listenForIncomingCalls();
        _observeRingingEvents();
        _listenForCoordinatorEvents();
        debugPrint('[VC] 📞 [StreamVideoService:initialize] Student listeners configured');
      } else {
        debugPrint('[VC] 📞 [StreamVideoService:initialize] User is MENTOR, skipping incoming call listeners');
      }

      // Mark as initialized only after successful setup
      _isInitialized = true;
      _isInitializing = false;
      debugPrint('[VC] 📞 [StreamVideoService:initialize] Service marked as initialized: $_isInitialized');

      notifyListeners();
      debugPrint('[VC] 📞 [StreamVideoService:initialize] << EXIT: Initialization complete successfully');
      _initializeCompleter?.complete();
      _initializeCompleter = null;
    } catch (e) {
      debugPrint('[VC] ❌ [StreamVideoService:initialize] << EXIT: Error during initialization: $e');
      debugPrint('[VC] ❌ [StreamVideoService:initialize] Stack trace: ${StackTrace.current}');
      _isInitialized = false;
      _isInitializing = false;
      _client = null;
      _initializeCompleter?.completeError(e, StackTrace.current);
      _initializeCompleter = null;
      rethrow;
    }
  }

  /// Verify token is not expired
  bool _verifyToken(String token) {
    return isTokenValid(token);
  }

  /// Check if a video token is valid (not expired).
  /// This is a static method so it can be called before initialization.
  static bool isTokenValid(String? token) {
    if (token == null || token.isEmpty) {
      debugPrint('[VC] 📞 [StreamVideoService:isTokenValid] Token is null or empty');
      return false;
    }

    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        debugPrint('[VC] 📞 [StreamVideoService:isTokenValid] Token is not a valid JWT (wrong number of parts)');
        return false;
      }

      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final decoded = utf8.decode(base64.decode(normalized));
      final jsonData = json.decode(decoded);

      if (jsonData['exp'] != null) {
        final expTime = DateTime.fromMillisecondsSinceEpoch(jsonData['exp'] * 1000);
        final isExpired = DateTime.now().isAfter(expTime);

        if (isExpired) {
          debugPrint('[VC] 📞 [StreamVideoService:isTokenValid] Token expired at: $expTime');
          return false;
        }

        debugPrint('[VC] 📞 [StreamVideoService:isTokenValid] Token valid until: $expTime');
      }

      return true;
    } catch (e) {
      debugPrint('[VC] ❌ [StreamVideoService:isTokenValid] Error verifying token: $e');
      return false;
    }
  }

  /// Listen for incoming calls (foreground - students only)
  /// Based on official pattern: listening to client.state.incomingCall
  void _listenForIncomingCalls() {
    debugPrint('[VC] 📞 [StreamVideoService:_listenForIncomingCalls] >> ENTRY: Setting up listener');

    _incomingCallSubscription?.cancel();

    _incomingCallSubscription = _client?.state.incomingCall.listen(
      (call) async {
        if (call == null) {
          debugPrint('[VC] 📞 [StreamVideoService:incomingCallListener] Incoming call cleared (set to null)');
          debugPrint('[VC] 📞 [StreamVideoService:incomingCallListener] Call was cancelled by caller or timed out');

          // Stop iOS timer since call is no longer active
          _stopIOSTimer();

          // End CallKit notification on Android when call is cancelled by mentor
          // This ensures the ringing stops when mentor cancels the call
          if (Platform.isAndroid && _incomingCallId != null) {
            debugPrint('[VC] 📞 [StreamVideoService:incomingCallListener] Ending CallKit notification for cancelled call');
            FlutterCallkitIncoming.endAllCalls().catchError((e) {
              debugPrint('[VC] ⚠️ [StreamVideoService:incomingCallListener] Error ending CallKit: $e');
            });
          }

          // iOS: End CallKit when call is cancelled
          if (Platform.isIOS && _incomingCallId != null) {
            await FlutterCallkitIncoming.endAllCalls();
          }

          _incomingCallId = null;
          _incomingCallerName = null;
          notifyListeners();
          return;
        }

        final callId = call.callCid.id;
        debugPrint('[VC] 📞 [StreamVideoService:incomingCallListener] ========== INCOMING CALL DETECTED ==========');
        debugPrint('[VC] 📞 [StreamVideoService:incomingCallListener] Call ID: $callId');
        debugPrint('[VC] 📞 [StreamVideoService:incomingCallListener] Call CID: ${call.callCid}');

        _incomingCallId = callId;

        // Get caller name from participants
        final participants = call.state.value.callParticipants;
        debugPrint('[VC] 📞 [StreamVideoService:incomingCallListener] Participants count: ${participants.length}');

        if (participants.isNotEmpty && participants.first.name.isNotEmpty) {
          _incomingCallerName = participants.first.name;
          debugPrint('[VC] 📞 [StreamVideoService:incomingCallListener] Caller name from participant: $_incomingCallerName');
        } else {
          _incomingCallerName = 'Mentor';
          debugPrint('[VC] 📞 [StreamVideoService:incomingCallListener] No participant name, using default: Mentor');
        }

        // Start iOS native timer to detect call cancellation while in background
        _startIOSTimer(call.callCid.toString());

        debugPrint('[VC] 📞 [StreamVideoService:incomingCallListener] Notifying listeners with new incoming call');
        notifyListeners();
        debugPrint('[VC] 📞 [StreamVideoService:incomingCallListener] ========== INCOMING CALL PROCESSING COMPLETE ==========');
      },
      onError: (error) {
        debugPrint('[VC] ❌ [StreamVideoService:incomingCallListener] Error in listener: $error');
        debugPrint('[VC] ❌ [StreamVideoService:incomingCallListener] Stack trace: ${StackTrace.current}');
      },
    );

    debugPrint('[VC] 📞 [StreamVideoService:_listenForIncomingCalls] << EXIT: Listener configured');
  }

  /// Observe ringing events for CallKit/push acceptance
  /// Based on official pattern from:
  /// https://getstream.io/video/sdk/flutter/tutorial/ringing/
  /// Note: observeCoreRingingEvents only has onCallAccepted callback.
  /// Call rejection and end events are handled via the incomingCall stream (call becomes null).
  void _observeRingingEvents() {
    debugPrint('[VC] 📞 [StreamVideoService:_observeRingingEvents] >> ENTRY: Setting up observer');

    _ringingEventsSubscription?.cancel();

    // Use Stream's observeCoreRingingEvents which handles CallKit/push accepts
    // The call is ALREADY JOINED when onCallAccepted fires
    // Note: Only onCallAccepted is available. Rejection/end are handled by incomingCall stream
    _ringingEventsSubscription = _client?.observeCoreRingingEvents(
      onCallAccepted: (callToJoin) async {
        debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] ========== CALL ACCEPTED VIA SDK ==========');
        debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] Call ID: ${callToJoin.id}');
        debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] Call CID: ${callToJoin.callCid}');
        debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] Call already joined: true');

        // Stop iOS timer - call was accepted
        _stopIOSTimer();

        // Cancel WorkManager monitoring and clear pending call since call was accepted
        if (Platform.isAndroid) {
          debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] Cancelling WorkManager monitor...');
          VideoCallNativeBridge.cancelCallMonitor(callId: callToJoin.id);
          debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] Clearing pending call...');
          VideoCallNativeBridge.clearPendingCall(callId: callToJoin.id);
        }

        _activeCall = callToJoin;
        _incomingCallId = null;
        _incomingCallerName = null;

        debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] Updated service state: activeCall set, incoming call cleared');
        debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] Callback registered: ${_onCallAcceptedCallback != null}');

        notifyListeners();
        debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] Listeners notified');

        // Invoke callback for navigation
        if (_onCallAcceptedCallback != null) {
          debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] Invoking navigation callback...');
          _onCallAcceptedCallback!(callToJoin);
          debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] Navigation callback invoked');
        } else {
          debugPrint('[VC] ⚠️ [StreamVideoService:onCallAccepted] No navigation callback registered!');
        }
        debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] ========== CALL ACCEPTED PROCESSING COMPLETE ==========');
      },
    );

    debugPrint('[VC] 📞 [StreamVideoService:_observeRingingEvents] << EXIT: Observer configured');
  }

  /// Listen for coordinator events (call rejected, ended, etc.)
  /// This provides explicit handling for when mentor cancels the call
  void _listenForCoordinatorEvents() {
    debugPrint('[VC] 📞 [StreamVideoService:_listenForCoordinatorEvents] >> ENTRY');

    _coordinatorEventsSubscription?.cancel();

    _coordinatorEventsSubscription = _client?.events.listen((event) async {
      debugPrint('[VC] 📞 [CoordinatorEvent] Received: ${event.runtimeType}');

      if (event is CoordinatorCallRejectedEvent) {
        debugPrint('[VC] 📞 [CoordinatorEvent] ========== CALL REJECTED ==========');
        debugPrint('[VC] 📞 [CoordinatorEvent] Call CID: ${event.callCid}');
        _handleCallCancelled('rejected');
      } else if (event is CoordinatorCallEndedEvent) {
        debugPrint('[VC] 📞 [CoordinatorEvent] ========== CALL ENDED ==========');
        debugPrint('[VC] 📞 [CoordinatorEvent] Call CID: ${event.callCid}');
        _handleCallCancelled('ended');
      } else if (event is CoordinatorCallSessionParticipantLeftEvent) {
        debugPrint('[VC] 📞 [CoordinatorEvent] ========== PARTICIPANT LEFT ==========');
        debugPrint('[VC] 📞 [CoordinatorEvent] Call CID: ${event.callCid}');
        // Only handle if it's the caller who left while we're still ringing
        if (_incomingCallId != null && _activeCall == null) {
          _handleCallCancelled('caller_left');
        }
      }
    });

    debugPrint('[VC] 📞 [StreamVideoService:_listenForCoordinatorEvents] << EXIT');
  }

  /// Handle call cancellation (rejected, ended, or caller left)
  void _handleCallCancelled(String reason) async {
    debugPrint('[VC] 📞 [StreamVideoService:_handleCallCancelled] Reason: $reason');

    // Stop iOS timer
    _stopIOSTimer();

    // End CallKit notification on both platforms
    // Always try to end, regardless of _incomingCallId state (may be cleared already)
    debugPrint('[VC] 📞 [StreamVideoService:_handleCallCancelled] Ending CallKit...');
    
    try {
      if (Platform.isIOS) {
        // Intentionally ignore activeCalls() result (kept for debugging).
        await FlutterCallkitIncoming.activeCalls();
      }
      
      await FlutterCallkitIncoming.endAllCalls();
      
      if (Platform.isIOS) {
        final after = await FlutterCallkitIncoming.activeCalls();
        
        // If endAllCalls failed to clear, use native fallback
        if (after.isNotEmpty) {
          const nativeChannel = MethodChannel('com.launchgo.app/callkit');
          try {
            await nativeChannel.invokeMethod('forceEndAllCalls');
            
            // Re-check
            await FlutterCallkitIncoming.activeCalls();
          } catch (e) {
          }
        }
      }
    } catch (e) {
      debugPrint('[VC] ⚠️ [StreamVideoService:_handleCallCancelled] Error: $e');
    }

    // Clear state
    _incomingCallId = null;
    _incomingCallerName = null;
    notifyListeners();

    debugPrint('[VC] 📞 [StreamVideoService:_handleCallCancelled] Call cancelled handling complete');
  }

  /// Consume and accept active call from terminated state (Android)
  /// Based on official pattern from:
  /// https://getstream.io/video/sdk/flutter/tutorial/ringing/
  void consumeAndAcceptActiveCall(OnCallAcceptedCallback onCallAccepted) {
    debugPrint('[VC] 📞 [StreamVideoService:consumeAndAcceptActiveCall] >> ENTRY');
    debugPrint('[VC] 📞 [StreamVideoService:consumeAndAcceptActiveCall] Checking for active call from terminated state...');
    debugPrint('[VC] 📞 [StreamVideoService:consumeAndAcceptActiveCall] Client exists: ${_client != null}');

    _client?.consumeAndAcceptActiveCall(
      onCallAccepted: (callToJoin) {
        debugPrint('[VC] 📞 [StreamVideoService:consumeCallback] ========== ACTIVE CALL CONSUMED ==========');
        debugPrint('[VC] 📞 [StreamVideoService:consumeCallback] Call ID: ${callToJoin.id}');
        debugPrint('[VC] 📞 [StreamVideoService:consumeCallback] Call CID: ${callToJoin.callCid}');
        debugPrint('[VC] 📞 [StreamVideoService:consumeCallback] This call was accepted while app was terminated');

        // Cancel WorkManager monitoring and clear pending call since call was accepted
        if (Platform.isAndroid) {
          debugPrint('[VC] 📞 [StreamVideoService:consumeCallback] Cancelling WorkManager monitor...');
          VideoCallNativeBridge.cancelCallMonitor(callId: callToJoin.id);
          debugPrint('[VC] 📞 [StreamVideoService:consumeCallback] Clearing pending call...');
          VideoCallNativeBridge.clearPendingCall(callId: callToJoin.id);
        }

        _activeCall = callToJoin;
        _incomingCallId = null;
        _incomingCallerName = null;

        debugPrint('[VC] 📞 [StreamVideoService:consumeCallback] Service state updated');
        notifyListeners();
        debugPrint('[VC] 📞 [StreamVideoService:consumeCallback] Listeners notified');

        debugPrint('[VC] 📞 [StreamVideoService:consumeCallback] Invoking provided callback for navigation...');
        onCallAccepted(callToJoin);
        debugPrint('[VC] 📞 [StreamVideoService:consumeCallback] ========== ACTIVE CALL CONSUMED COMPLETE ==========');
      },
    );

    debugPrint('[VC] 📞 [StreamVideoService:consumeAndAcceptActiveCall] << EXIT: Consume request sent to SDK');
  }

  /// Handle ringing flow notifications (for Firebase background messages)
  /// Based on official pattern from:
  /// https://getstream.io/video/sdk/flutter/tutorial/ringing/
  Future<bool> handleRingingFlowNotifications(Map<String, dynamic> data) async {
    debugPrint('[VC] 📞 [StreamVideoService:handleRingingFlowNotifications] >> ENTRY');
    debugPrint('[VC] 📞 [StreamVideoService:handleRingingFlowNotifications] Push data: $data');
    debugPrint('[VC] 📞 [StreamVideoService:handleRingingFlowNotifications] Client initialized: ${_client != null}');

    if (_client == null) {
      debugPrint('[VC] ❌ [StreamVideoService:handleRingingFlowNotifications] << EXIT: Client not initialized');
      return false;
    }

    try {
      debugPrint('[VC] 📞 [StreamVideoService:handleRingingFlowNotifications] Passing notification to Stream Video SDK...');
      final result = await _client!.handleRingingFlowNotifications(data);
      debugPrint('[VC] 📞 [StreamVideoService:handleRingingFlowNotifications] SDK handled notification: $result');
      debugPrint('[VC] 📞 [StreamVideoService:handleRingingFlowNotifications] << EXIT: Success (handled=$result)');
      return result;
    } catch (e) {
      debugPrint('[VC] ❌ [StreamVideoService:handleRingingFlowNotifications] << EXIT: Error: $e');
      debugPrint('[VC] ❌ [StreamVideoService:handleRingingFlowNotifications] Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Set active call (helper for VideoChatScreen)
  void setActiveCall(Call call) {
    debugPrint('[VC] 📞 [StreamVideoService:setActiveCall] Setting active call: ${call.id}');
    _activeCall = call;
    _incomingCallId = null;
    _incomingCallerName = null;
    notifyListeners();
  }

  /// Clear active call (helper for VideoChatScreen)
  void clearActiveCall() async {
    debugPrint('[VC] 📞 [StreamVideoService:clearActiveCall] Clearing active call');
    
    // End CallKit when clearing active call
    if (Platform.isIOS) {
      try {
        await FlutterCallkitIncoming.endAllCalls();
        final after = await FlutterCallkitIncoming.activeCalls();
        
        // If endAllCalls failed to clear, use native fallback
        if (after.isNotEmpty) {
          const nativeChannel = MethodChannel('com.launchgo.app/callkit');
          try {
            await nativeChannel.invokeMethod('forceEndAllCalls');
            
            // Re-check
            await FlutterCallkitIncoming.activeCalls();
          } catch (e) {
          }
        }
      } catch (e) {
      }
    }
    
    _activeCall = null;
    notifyListeners();
  }

  /// Reject an incoming call by ID (for CallKit decline action)
  /// This is used when user taps Decline on the notification
  Future<void> rejectIncomingCall(String callId) async {
    debugPrint('[VC] 📞 =====================================================');
    debugPrint('[VC] 📞 [StreamVideoService:rejectIncomingCall] >> ENTRY');
    debugPrint('[VC] 📞 =====================================================');
    debugPrint('[VC] 📞 Call ID: $callId');
    debugPrint('[VC] 📞 Client initialized: ${_client != null}');
    debugPrint('[VC] 📞 Is initialized flag: $_isInitialized');

    if (_client == null) {
      debugPrint('[VC] ❌ [StreamVideoService:rejectIncomingCall] << EXIT: Client not initialized');
      return;
    }

    try {
      // Create call reference
      debugPrint('[VC] 📞 Creating call reference with StreamCallType.defaultType()...');
      final call = _client!.makeCall(
        callType: StreamCallType.defaultType(),
        id: callId,
      );
      debugPrint('[VC] 📞 Call reference created: ${call.callCid}');

      // Fetch the call to ensure it exists
      debugPrint('[VC] 📞 Calling getOrCreate()...');
      await call.getOrCreate();
      debugPrint('[VC] 📞 getOrCreate() completed');
      debugPrint('[VC] 📞 Call state status: ${call.state.value.status}');
      debugPrint('[VC] 📞 Call participants: ${call.state.value.callParticipants.length}');

      // Reject the call
      debugPrint('[VC] 📞 Calling call.reject()...');
      await call.reject();
      debugPrint('[VC] 📞 call.reject() completed');

      debugPrint('[VC] 📞 Call rejected successfully - caller should receive notification');

      // End CallKit notification on Android
      if (Platform.isAndroid) {
        debugPrint('[VC] 📞 Ending CallKit notification...');
        await FlutterCallkitIncoming.endAllCalls();
        debugPrint('[VC] 📞 CallKit ended');
      }

      // Clear incoming call state
      _incomingCallId = null;
      _incomingCallerName = null;
      notifyListeners();

      debugPrint('[VC] 📞 =====================================================');
      debugPrint('[VC] 📞 [StreamVideoService:rejectIncomingCall] << EXIT: SUCCESS');
      debugPrint('[VC] 📞 =====================================================');
    } catch (e, stackTrace) {
      debugPrint('[VC] ❌ =====================================================');
      debugPrint('[VC] ❌ [StreamVideoService:rejectIncomingCall] ERROR');
      debugPrint('[VC] ❌ =====================================================');
      debugPrint('[VC] ❌ Error: $e');
      debugPrint('[VC] ❌ Stack trace: $stackTrace');

      // Still try to end CallKit on error
      if (Platform.isAndroid) {
        debugPrint('[VC] 📞 Trying to end CallKit despite error...');
        FlutterCallkitIncoming.endAllCalls().catchError((err) {
          debugPrint('[VC] ⚠️ Error ending CallKit: $err');
        });
      }

      // Still clear the state even on error
      _incomingCallId = null;
      _incomingCallerName = null;
      notifyListeners();
      debugPrint('[VC] ❌ =====================================================');
    }
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    debugPrint('[VC] 📞 [StreamVideoService:disconnect] Disconnecting service');
    debugPrint('[VC] 📞 [StreamVideoService:disconnect] BEGIN (expect no devices left after this)');

    // Cancel any in-flight initialization so callers don't wait forever.
    _isInitializing = false;
    if (_initializeCompleter != null && !_initializeCompleter!.isCompleted) {
      _initializeCompleter!.completeError(Exception('StreamVideoService disconnected during initialization'));
    }
    _initializeCompleter = null;

    await _incomingCallSubscription?.cancel();
    _incomingCallSubscription = null;

    _ringingEventsSubscription?.cancel();
    _ringingEventsSubscription = null;

    await _coordinatorEventsSubscription?.cancel();
    _coordinatorEventsSubscription = null;

    // IMPORTANT: Unregister ALL devices from Stream Video before disconnecting
    // This stops VoIP pushes from being sent to this device after logout
    if (_client != null) {
      try {
        debugPrint('[VC] 📞 [StreamVideoService:disconnect] Unregistering devices from Stream Video...');
        
        // iOS: Explicitly remove VoIP token first (most reliable approach)
        if (Platform.isIOS) {
          try {
            final voipToken = await VoipPushKitService.getVoipToken();
            if (voipToken != null && voipToken.isNotEmpty) {
              debugPrint('[VC] 📞 [StreamVideoService:disconnect] Explicitly removing iOS VoIP token: ${voipToken.substring(0, 16)}...');
              await _client!.removeDevice(pushToken: voipToken);
              debugPrint('[VC] ✅ [StreamVideoService:disconnect] iOS VoIP token removed');
            } else {
              debugPrint('[VC] 📞 [StreamVideoService:disconnect] No iOS VoIP token available to remove');
            }
          } catch (e) {
            debugPrint('[VC] ⚠️ [StreamVideoService:disconnect] Error removing iOS VoIP token: $e');
          }
        }
        
        // Then query and remove all other devices (catch-all for any others)
        final devicesResult = await _client!.getDevices();
        
        if (devicesResult.isSuccess) {
          final devices = devicesResult.getDataOrNull() ?? [];
          debugPrint('[VC] 📞 [StreamVideoService:disconnect] Found ${devices.length} registered devices');
          for (final device in devices) {
            debugPrint('[VC] 📞 [StreamVideoService:disconnect] Removing device: ${device.pushToken}');
            try {
              await _client!.removeDevice(pushToken: device.pushToken);
              debugPrint('[VC] ✅ [StreamVideoService:disconnect] Device removed: ${device.pushToken}');
            } catch (e) {
              debugPrint('[VC] ⚠️ [StreamVideoService:disconnect] Error removing device: $e');
            }
          }
        } else {
          debugPrint('[VC] ⚠️ [StreamVideoService:disconnect] Error getting devices: ${devicesResult.toString()}');
        }
      } catch (e) {
        debugPrint('[VC] ⚠️ [StreamVideoService:disconnect] Error unregistering devices: $e');
        // Don't fail disconnect if device unregistration fails
      }
    }

    await _client?.disconnect();
    _client = null;

    // iOS: Clear native auth so a logged-out device cannot reject/act on calls.
    if (Platform.isIOS) {
      try {
        await _iosStreamVideoAuthChannel.invokeMethod('clear');
      } catch (_) {}
    }

    _activeCall = null;
    _incomingCallId = null;
    _incomingCallerName = null;
    _isInitialized = false;

    notifyListeners();
    debugPrint('[VC] 📞 [StreamVideoService:disconnect] Service disconnected');
    debugPrint('[VC] 📞 [StreamVideoService:disconnect] END');
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
