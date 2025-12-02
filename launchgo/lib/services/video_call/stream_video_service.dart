import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart' as callkit_entities;
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';
import '../../config/environment.dart';
import '../../models/user_model.dart';

/// Service for managing Stream Video calls
/// Only mentors can initiate calls, students can only receive
class StreamVideoService extends ChangeNotifier {
  StreamVideo? _client;
  Call? _activeCall;
  Call? _incomingCall; // Store the actual incoming Call object
  String? _incomingCallId;
  String? _incomingCallerName;
  bool _isInitialized = false;
  StreamSubscription<Call?>? _incomingCallSubscription; // Track the subscription to prevent duplicates
  String? _lastProcessedCallId; // Track the last call we processed to prevent duplicates
  String? _pendingCallId; // Call ID when app wakes from terminated state via CallKit
  StreamSubscription? _callKitSubscription; // CallKit event listener

  StreamVideo? get client => _client;
  Call? get activeCall => _activeCall;
  bool get hasActiveCall => _activeCall != null;
  String? get incomingCallId => _incomingCallId;
  String? get incomingCallerName => _incomingCallerName;
  bool get isInitialized => _isInitialized;

  /// Initialize the video client for the authenticated user
  Future<void> initialize(UserModel user) async {
    debugPrint('📞 [INIT] StreamVideoService.initialize() called for user: ${user.id}');
    debugPrint('📞 [INIT] User role: ${user.role}');

    // Skip if already initialized
    if (_isInitialized) {
      debugPrint('⚠️ StreamVideoService already initialized, skipping');
      return;
    }

    // Set initialized flag immediately to prevent concurrent initialization attempts
    _isInitialized = true;
    debugPrint('📞 [INIT] Marked as initialized to prevent race conditions');

    try {
      final apiKey = EnvironmentConfig.streamVideoApiKey;
      debugPrint('📞 [INIT] API Key exists: ${apiKey.isNotEmpty}');

      // Get token from user's API data
      String callGetStreamToken = user.callGetStreamToken ?? '';

      debugPrint('📞 [INIT] Has video token: ${callGetStreamToken.isNotEmpty}');

      if (callGetStreamToken.isEmpty) {
        debugPrint('❌ [INIT] No video call token found for user ${user.id}');
        return;
      }

      if (callGetStreamToken.isNotEmpty) {
        try {
          // Decode JWT to check expiration (basic parsing, not validation)
          final parts = callGetStreamToken.split('.');
          if (parts.length == 3) {
            final payload = parts[1];
            // Add padding if needed
            final normalized = base64.normalize(payload);
            final decoded = utf8.decode(base64.decode(normalized));
            debugPrint('📞 Stream Video Token Info: $decoded');

            // Parse expiration time
            final jsonData = json.decode(decoded);
            if (jsonData['exp'] != null) {
              final expTime = DateTime.fromMillisecondsSinceEpoch(jsonData['exp'] * 1000);
              final now = DateTime.now();
              final isExpired = now.isAfter(expTime);
              final timeLeft = expTime.difference(now);

              debugPrint('📞 Token expires at: $expTime');
              debugPrint('📞 Current time: $now');
              debugPrint('📞 Token expired: $isExpired');
              if (!isExpired) {
                debugPrint('📞 Time until expiration: ${timeLeft.inMinutes} minutes');
              }

              if (isExpired) {
                debugPrint('❌ [INIT] Stream Video token has EXPIRED! Token expired at: $expTime, Current time: $now');
                debugPrint('❌ [INIT] No valid token available. User needs to re-authenticate.');
                return;
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Could not parse token expiration: $e');
        }
      }

      _client = StreamVideo(
        apiKey,
        user: User.regular(
          userId: user.id,
          name: user.name,
          image: user.avatarUrl,
        ),
        userToken: callGetStreamToken,
        options: const StreamVideoOptions(
          logPriority: Priority.verbose,
        ),
        pushNotificationManagerProvider: StreamVideoPushNotificationManager.create(
          iosPushProvider: const StreamVideoPushProvider.apn(
            name: 'voip_apns',//'apn',
          ),
          androidPushProvider: const StreamVideoPushProvider.firebase(
            name: 'firebase',
          ),
        ),
      );

      // Connect to establish WebSocket for receiving incoming call events
      debugPrint('📞 Connecting Stream Video client...');
      await _client!.connect();
      debugPrint('✅ Stream Video client connected');

      await _logVoIPToken();

      // Listen for incoming calls (for students)
      if (user.role == UserRole.student) {
        debugPrint('📞 User is a student, setting up incoming call listener');
        _listenForIncomingCalls();
        _setupCallKitListener(); // Listen for CallKit events (accept/decline from native UI)
      } else {
        debugPrint('📞 User is a mentor, skipping incoming call listener');
      }

      // Process any pending call from CallKit (app woke from terminated state)
      if (_pendingCallId != null) {
        final pendingId = _pendingCallId!;
        _pendingCallId = null;
        debugPrint('📞 Processing pending call from CallKit: $pendingId');
        await handleCallKitAccept(pendingId);
      }

      notifyListeners();
      debugPrint('✅ [INIT] StreamVideoService initialized for user: ${user.id} (role: ${user.role})');
    } catch (e) {
      debugPrint('❌ [INIT] Error initializing StreamVideoService: $e');
      debugPrint('❌ [INIT] Stack trace: ${StackTrace.current}');
      // Reset the flag so initialization can be retried
      _isInitialized = false;
    }
  }

  /// Retrieve and log VoIP device token from flutter_callkit_incoming
  Future<void> _logVoIPToken() async {
    try {
      const platform = MethodChannel('flutter_callkit_incoming');
      final String voipToken = await platform.invokeMethod('getDevicePushTokenVoIP');
      debugPrint('📞 VoIP Device Token: $voipToken');
    } catch (e) {
      debugPrint('Error retrieving VoIP token: $e');
    }
  }

  /// Listen for incoming calls (students only)
  void _listenForIncomingCalls() {
    debugPrint('📞 Setting up incoming call listener for student');

    // Cancel existing subscription to prevent duplicates
    _incomingCallSubscription?.cancel();
    debugPrint('📞 Cancelled previous incoming call subscription (if any)');

    _incomingCallSubscription = _client?.state.incomingCall.listen(
      (call) {
        debugPrint('📞 Incoming call listener triggered! Call: $call');

        if (call == null) {
          // Call was cancelled or rejected
          debugPrint('📞 Call was cancelled or rejected');
          _incomingCall = null;
          _incomingCallId = null;
          _incomingCallerName = null;
          _lastProcessedCallId = null;
          notifyListeners();
          return;
        }

        final callId = call.callCid.id;
        debugPrint('📞 Incoming video call detected: ${call.callCid}');

        // Prevent processing the same call multiple times (deduplication)
        if (_lastProcessedCallId == callId) {
          debugPrint('📞 Already processed this call, ignoring duplicate event: $callId');
          return;
        }

        _lastProcessedCallId = callId;
        _incomingCall = call; // Store the actual Call object
        _incomingCallId = callId; // Also store ID for display

        // Set a default caller name immediately
        _incomingCallerName = 'Mentor';

        // Notify immediately so the incoming call screen appears
        notifyListeners();
        debugPrint('📞 Notified listeners of incoming call - incomingCallId: $_incomingCallId');

        // Try to get actual caller name from call state (this updates the name if available)
        call.state.listen((callState) {
          final remoteParticipants = callState.callParticipants.where((p) => !p.isLocal).toList();

          if (remoteParticipants.isNotEmpty && remoteParticipants.first.name.isNotEmpty) {
            _incomingCallerName = remoteParticipants.first.name;
            notifyListeners();
            debugPrint('📞 Updated caller name: $_incomingCallerName');
          }
        });
      },
      onError: (error) {
        debugPrint('❌ Error in incoming call listener: $error');
      },
      onDone: () {
        debugPrint('⚠️ Incoming call listener stream closed');
      },
    );

    debugPrint('✅ Incoming call listener setup complete');
  }

  /// Create and initiate a call (mentor only)
  /// callId should be the student's ID for consistency
  Future<Call?> createCall({
    required String callId,
    required String recipientId,
    required String recipientName,
  }) async {
    debugPrint('📞 createCall called - callId: $callId, recipientId: $recipientId, recipientName: $recipientName');

    if (_client == null) {
      debugPrint('❌ Video client not initialized');
      return null;
    }

    try {
      // Clean up any stale active call before creating a new one
      if (_activeCall != null) {
        debugPrint('⚠️ Cleaning up stale active call before creating new one');
        try {
          await _activeCall!.leave();
          // Don't set _activeCall = null or call notifyListeners() here
          // to avoid race condition where VideoCallScreen sees null
        } catch (e) {
          debugPrint('⚠️ Error leaving stale call: $e');
        }
      }

      debugPrint('📞 Creating call to student: $recipientId');

      final call = _client!.makeCall(
        callType: StreamCallType.defaultType(),
        id: callId,
      );

      debugPrint('📞 Call object created, calling getOrCreate with ringing: true');

      await call.getOrCreate(
        memberIds: [recipientId],
        ringing: true, // This triggers incoming call notification
      );

      debugPrint('📞 getOrCreate completed - setting activeCall for UI');

      // Set activeCall immediately so mentor sees "calling" UI right away
      _activeCall = call;
      notifyListeners();

      debugPrint('✅ Call created successfully: $callId - returning immediately for UI');

      // CRITICAL: Caller must explicitly join the call
      // Start join in background so UI shows immediately
      debugPrint('📞 Starting join in background...');
      call.join().then((_) {
        debugPrint('✅ Caller joined the call successfully');
        debugPrint('📞 Active call members: ${call.state.value.callParticipants.map((p) => p.userId).toList()}');
      }).catchError((error) {
        debugPrint('❌ Error joining call: $error');
      });

      // Return immediately so navigation can happen without waiting for join
      return call;
    } catch (e) {
      debugPrint('❌ Error creating call: $e');
      return null;
    }
  }

  /// Accept an incoming call (student only)
  /// [callId] - Optional call ID to use when _incomingCall is null (e.g., app was terminated)
  Future<Call?> acceptIncomingCall({String? callId}) async {
    if (_client == null) {
      debugPrint('❌ Cannot accept call: client is null');
      return null;
    }

    try {
      Call call;

      if (_incomingCall != null) {
        // Best case: Use the actual Call object from the incoming call listener
        call = _incomingCall!;
        debugPrint('📞 Using incoming Call object: ${call.id}');
      } else if (callId != null) {
        // App was terminated - fetch call by ID
        debugPrint('📞 _incomingCall is null, fetching call by ID: $callId');

        call = _client!.makeCall(
          callType: StreamCallType.defaultType(),
          id: callId,
        );

        // Get the existing call
        await call.getOrCreate();
        debugPrint('📞 Call fetched successfully: ${call.id}');
      } else {
        debugPrint('❌ Cannot accept call: no incoming call and no callId provided');
        return null;
      }

      debugPrint('📞 Now accepting and joining call...');

      // CRITICAL: Callee must explicitly accept AND join the call
      await call.accept();
      debugPrint('✅ Call accepted');

      await call.join();
      debugPrint('✅ Callee joined the call successfully');

      _activeCall = call;
      _incomingCall = null;
      _incomingCallId = null;
      _incomingCallerName = null;
      _lastProcessedCallId = null;
      notifyListeners();

      debugPrint('✅ Call accepted and joined - ready for StreamCallContainer');
      return call;
    } catch (e) {
      debugPrint('❌ Error accepting call: $e');
      return null;
    }
  }

  /// Decline an incoming call (student only)
  Future<void> declineIncomingCall() async {
    if (_client == null || _incomingCall == null) {
      debugPrint('Cannot decline call: client or incoming call is null');
      return;
    }

    try {
      debugPrint('Declining incoming call: ${_incomingCall!.id}');

      // Use the actual Call object to reject
      await _incomingCall!.reject();

      _incomingCall = null;
      _incomingCallId = null;
      _incomingCallerName = null;
      _lastProcessedCallId = null; // Clear so next call can be processed
      notifyListeners();

      debugPrint('Call declined successfully');

      // NOTE: No need to re-establish listener - it remains active for next call
    } catch (e) {
      debugPrint('Error declining call: $e');
    }
  }

  /// Join an existing call
  Future<void> joinCall(Call call) async {
    try {
      await call.join();
      _activeCall = call;
      notifyListeners();
      debugPrint('Joined call successfully');
    } catch (e) {
      debugPrint('Error joining call: $e');
    }
  }

  /// End the active call
  Future<void> endCall() async {
    if (_activeCall == null) {
      debugPrint('No active call to end');
      return;
    }

    try {
      final callId = _activeCall!.id;
      debugPrint('Ending call: $callId');

      await _activeCall!.leave();
      _activeCall = null;
      _lastProcessedCallId = null; // Clear to allow next call with same ID
      notifyListeners();
      debugPrint('Call ended successfully');

      // NOTE: No need to re-establish listener - it remains active for next call
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    await endCall();
    await _incomingCallSubscription?.cancel();
    _incomingCallSubscription = null;
    await _callKitSubscription?.cancel();
    _callKitSubscription = null;
    await _client?.disconnect();
    _client = null;
    _incomingCall = null;
    _incomingCallId = null;
    _incomingCallerName = null;
    _lastProcessedCallId = null;
    _pendingCallId = null;
    _isInitialized = false; // Reset so new user can initialize
    notifyListeners();
    debugPrint('StreamVideoService disconnected');
  }

  /// Setup CallKit event listener for native iOS call UI
  void _setupCallKitListener() {
    debugPrint('📞 Setting up CallKit event listener');

    // Cancel existing subscription
    _callKitSubscription?.cancel();

    _callKitSubscription = FlutterCallkitIncoming.onEvent.listen((callkit_entities.CallEvent? event) {
      if (event == null) return;

      debugPrint('📞 CallKit event received: ${event.event}');
      debugPrint('📞 CallKit event body: ${event.body}');

      final callId = event.body['id'] as String?;
      if (callId == null) {
        debugPrint('⚠️ CallKit event has no call ID');
        return;
      }

      switch (event.event) {
        case callkit_entities.Event.actionCallAccept:
          debugPrint('📞 CallKit: User accepted call $callId');
          handleCallKitAccept(callId);
          break;
        case callkit_entities.Event.actionCallDecline:
          debugPrint('📞 CallKit: User declined call $callId');
          handleCallKitDecline(callId);
          break;
        case callkit_entities.Event.actionCallEnded:
          debugPrint('📞 CallKit: Call ended $callId');
          break;
        case callkit_entities.Event.actionCallTimeout:
          debugPrint('📞 CallKit: Call timeout $callId');
          break;
        default:
          debugPrint('📞 CallKit: Unhandled event ${event.event}');
          break;
      }
    });

    debugPrint('✅ CallKit event listener setup complete');
  }

  /// Handle CallKit accept action (user accepted from native iOS call UI)
  Future<void> handleCallKitAccept(String callId) async {
    debugPrint('📞 handleCallKitAccept called for call: $callId');

    // If client isn't initialized yet, store the pending call for later
    if (_client == null) {
      debugPrint('📞 Client not ready, storing pending call: $callId');
      _pendingCallId = callId;
      return;
    }

    // Accept and join the call using existing method
    final call = await acceptIncomingCall(callId: callId);
    if (call != null) {
      debugPrint('✅ Call accepted from CallKit: $callId');
      // Navigation will be handled by the listener in main.dart
    } else {
      debugPrint('❌ Failed to accept call from CallKit: $callId');
    }
  }

  /// Handle CallKit decline action (user declined from native iOS call UI)
  Future<void> handleCallKitDecline(String callId) async {
    debugPrint('📞 handleCallKitDecline called for call: $callId');

    if (_client == null) {
      debugPrint('⚠️ Client not initialized, cannot decline call');
      return;
    }

    try {
      // Create call object to reject
      final call = _client!.makeCall(
        callType: StreamCallType.defaultType(),
        id: callId,
      );
      await call.getOrCreate();
      await call.reject();

      debugPrint('✅ Call declined from CallKit: $callId');
    } catch (e) {
      debugPrint('❌ Error declining call from CallKit: $e');
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
