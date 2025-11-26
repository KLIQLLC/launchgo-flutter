import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../../config/environment.dart';
import '../../models/user_model.dart';

/// Service for managing Stream Video calls
/// Only mentors can initiate calls, students can only receive
class StreamVideoService extends ChangeNotifier {
  StreamVideo? _client;
  Call? _activeCall;
  String? _incomingCallId;
  String? _incomingCallerName;
  bool _isInitialized = false;
  StreamSubscription<Call?>? _incomingCallSubscription; // Track the subscription to prevent duplicates
  String? _lastProcessedCallId; // Track the last call we processed to prevent duplicates

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
      String token = user.callGetStreamToken ?? '';

      debugPrint('📞 [INIT] Has video token: ${token.isNotEmpty}');

      if (token.isEmpty) {
        debugPrint('❌ [INIT] No video call token found for user ${user.id}');
        return;
      }

      if (token.isNotEmpty) {
        try {
          // Decode JWT to check expiration (basic parsing, not validation)
          final parts = token.split('.');
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
        userToken: token,
        // TODO: Add VoIP push notifications after fixing package compilation issue
        // For now, incoming calls work via WebSocket when app is in foreground
      );

      // Connect to establish WebSocket for receiving incoming call events
      debugPrint('📞 Connecting Stream Video client...');
      await _client!.connect();
      debugPrint('✅ Stream Video client connected');

      // Listen for incoming calls (for students)
      if (user.role == UserRole.student) {
        debugPrint('📞 User is a student, setting up incoming call listener');
        _listenForIncomingCalls();
      } else {
        debugPrint('📞 User is a mentor, skipping incoming call listener');
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
        _incomingCallId = callId; // Use just the ID, not the full CID value

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

      debugPrint('📞 getOrCreate completed, joining call...');

      // Join the call immediately after creating it (mentor side)
      try {
        final result = await call.join();
        debugPrint('📞 join() returned: $result');
      } catch (e, stackTrace) {
        debugPrint('❌ Error during call.join(): $e');
        debugPrint('❌ Stack trace: $stackTrace');
        rethrow;
      }

      _activeCall = call;
      notifyListeners();

      debugPrint('✅ Call created and joined successfully: $callId');
      debugPrint('📞 Active call members: ${call.state.value.callParticipants.map((p) => p.userId).toList()}');
      return call;
    } catch (e) {
      debugPrint('❌ Error creating call: $e');
      return null;
    }
  }

  /// Accept an incoming call (student only)
  Future<Call?> acceptIncomingCall() async {
    if (_client == null || _incomingCallId == null) {
      debugPrint('Cannot accept call: client or callId is null');
      return null;
    }

    try {
      debugPrint('Accepting incoming call: $_incomingCallId');

      final call = _client!.makeCall(
        callType: StreamCallType.defaultType(),
        id: _incomingCallId!,
      );

      await call.join();

      _activeCall = call;
      _incomingCallId = null;
      _incomingCallerName = null;
      _lastProcessedCallId = null; // Clear so next call can be processed
      notifyListeners();

      debugPrint('Call accepted successfully');
      return call;
    } catch (e) {
      debugPrint('Error accepting call: $e');
      return null;
    }
  }

  /// Decline an incoming call (student only)
  Future<void> declineIncomingCall() async {
    if (_client == null || _incomingCallId == null) {
      debugPrint('Cannot decline call: client or callId is null');
      return;
    }

    try {
      debugPrint('Declining incoming call: $_incomingCallId');

      final call = _client!.makeCall(
        callType: StreamCallType.defaultType(),
        id: _incomingCallId!,
      );

      await call.reject();

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
      debugPrint('Ending call: ${_activeCall!.id}');
      await _activeCall!.leave();
      _activeCall = null;
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
    await _client?.disconnect();
    _client = null;
    _incomingCallId = null;
    _incomingCallerName = null;
    _lastProcessedCallId = null;
    notifyListeners();
    debugPrint('StreamVideoService disconnected');
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
