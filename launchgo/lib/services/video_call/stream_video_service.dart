import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';
import '../../config/environment.dart';
import '../../models/user_model.dart';

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

  StreamSubscription<Call?>? _incomingCallSubscription;
  CompositeSubscription? _ringingEventsSubscription;
  OnCallAcceptedCallback? _onCallAcceptedCallback;

  StreamVideo? get client => _client;
  Call? get activeCall => _activeCall;
  bool get hasActiveCall => _activeCall != null;
  String? get incomingCallId => _incomingCallId;
  String? get incomingCallerName => _incomingCallerName;
  bool get isInitialized => _isInitialized;

  /// Set callback for when call is accepted via CallKit/push (for navigation)
  void setOnCallAcceptedCallback(OnCallAcceptedCallback? callback) {
    _onCallAcceptedCallback = callback;
    debugPrint('[VIDEO_CALL] Callback set for call acceptance');
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
      debugPrint('[VC] 📞 [StreamVideoService:initialize] << EXIT: Already initializing in progress, skipping');
      return;
    }

    _isInitializing = true;

    try {
      final apiKey = EnvironmentConfig.streamVideoApiKey;
      final token = user.callGetStreamToken ?? '';

      if (token.isEmpty) {
        debugPrint('[VC] ❌ [StreamVideoService:initialize] << EXIT: No video token available');
        _isInitializing = false;
        return;
      }

      // Verify token not expired
      debugPrint('[VC] 📞 [StreamVideoService:initialize] Verifying token validity...');
      if (!_verifyToken(token)) {
        debugPrint('[VC] ❌ [StreamVideoService:initialize] << EXIT: Token expired');
        _isInitializing = false;
        return;
      }
      debugPrint('[VC] 📞 [StreamVideoService:initialize] Token is valid');

      // Reset singleton state only if we're reinitializing
      if (_client != null || _isInitialized) {
        debugPrint('[VC] 📞 [StreamVideoService:initialize] Existing client/state found, resetting singleton...');
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
            name: 'firebase',
          ),
        ),
      );

      // Connect to establish WebSocket
      debugPrint('[VC] 📞 [StreamVideoService:initialize] Connecting to Stream Video WebSocket...');
      await _client!.connect();
      debugPrint('[VC] 📞 [StreamVideoService:initialize] WebSocket connected successfully');

      // Set up listeners based on user role
      if (user.role == UserRole.student) {
        debugPrint('[VC] 📞 [StreamVideoService:initialize] User is STUDENT, setting up incoming call listeners...');
        _listenForIncomingCalls();
        _observeRingingEvents();
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
    } catch (e) {
      debugPrint('[VC] ❌ [StreamVideoService:initialize] << EXIT: Error during initialization: $e');
      debugPrint('[VC] ❌ [StreamVideoService:initialize] Stack trace: ${StackTrace.current}');
      _isInitialized = false;
      _isInitializing = false;
      _client = null;
    }
  }

  /// Verify token is not expired
  bool _verifyToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final decoded = utf8.decode(base64.decode(normalized));
      final jsonData = json.decode(decoded);

      if (jsonData['exp'] != null) {
        final expTime = DateTime.fromMillisecondsSinceEpoch(jsonData['exp'] * 1000);
        final isExpired = DateTime.now().isAfter(expTime);

        if (isExpired) {
          debugPrint('[VIDEO_CALL] Token expired at: $expTime');
          return false;
        }

        debugPrint('[VIDEO_CALL] Token valid until: $expTime');
      }

      return true;
    } catch (e) {
      debugPrint('[VIDEO_CALL] Error verifying token: $e');
      return false;
    }
  }

  /// Listen for incoming calls (foreground - students only)
  /// Based on official pattern: listening to client.state.incomingCall
  void _listenForIncomingCalls() {
    debugPrint('[VC] 📞 [StreamVideoService:_listenForIncomingCalls] >> ENTRY: Setting up listener');

    _incomingCallSubscription?.cancel();

    _incomingCallSubscription = _client?.state.incomingCall.listen(
      (call) {
        if (call == null) {
          debugPrint('[VC] 📞 [StreamVideoService:incomingCallListener] Incoming call cleared (set to null)');
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
      onCallAccepted: (callToJoin) {
        debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] ========== CALL ACCEPTED VIA SDK ==========');
        debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] Call ID: ${callToJoin.id}');
        debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] Call CID: ${callToJoin.callCid}');
        debugPrint('[VC] 📞 [StreamVideoService:onCallAccepted] Call already joined: true');

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
    debugPrint('[VIDEO_CALL] Setting active call: ${call.id}');
    _activeCall = call;
    _incomingCallId = null;
    _incomingCallerName = null;
    notifyListeners();
  }

  /// Clear active call (helper for VideoChatScreen)
  void clearActiveCall() {
    debugPrint('[VIDEO_CALL] Clearing active call');
    _activeCall = null;
    notifyListeners();
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    debugPrint('[VIDEO_CALL] Disconnecting service');

    await _incomingCallSubscription?.cancel();
    _incomingCallSubscription = null;

    _ringingEventsSubscription?.cancel();
    _ringingEventsSubscription = null;

    await _client?.disconnect();
    _client = null;

    _activeCall = null;
    _incomingCallId = null;
    _incomingCallerName = null;
    _isInitialized = false;

    notifyListeners();
    debugPrint('[VIDEO_CALL] Service disconnected');
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
