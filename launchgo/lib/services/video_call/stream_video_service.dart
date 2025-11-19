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

  StreamVideo? get client => _client;
  Call? get activeCall => _activeCall;
  bool get hasActiveCall => _activeCall != null;
  String? get incomingCallId => _incomingCallId;
  String? get incomingCallerName => _incomingCallerName;

  /// Initialize the video client for the authenticated user
  Future<void> initialize(UserModel user) async {
    try {
      final apiKey = EnvironmentConfig.streamVideoApiKey;

      _client = StreamVideo(
        apiKey,
        user: User.regular(
          userId: user.id,
          name: user.name,
          image: user.avatarUrl,
        ),
        userToken: user.getStreamToken ?? '',
      );

      // Listen for incoming calls (for students)
      if (user.role == UserRole.student) {
        _listenForIncomingCalls();
      }

      notifyListeners();
      debugPrint('StreamVideoService initialized for user: ${user.id}');
    } catch (e) {
      debugPrint('Error initializing StreamVideoService: $e');
    }
  }

  /// Listen for incoming calls (students only)
  void _listenForIncomingCalls() {
    _client?.state.incomingCall.listen((call) {
      if (call == null) return;

      debugPrint('Incoming call from: ${call.callCid}');
      _incomingCallId = call.callCid.value;

      // Get caller name from call state
      call.state.listen((callState) {
        final remoteParticipants = callState.callParticipants.where((p) => !p.isLocal).toList();

        if (remoteParticipants.isNotEmpty) {
          _incomingCallerName = remoteParticipants.first.name;
          notifyListeners();
        }
      });
    });
  }

  /// Create and initiate a call (mentor only)
  /// callId should be the student's ID for consistency
  Future<Call?> createCall({
    required String callId,
    required String recipientId,
    required String recipientName,
  }) async {
    if (_client == null) {
      debugPrint('Video client not initialized');
      return null;
    }

    try {
      debugPrint('Creating call to student: $recipientId');

      final call = _client!.makeCall(
        callType: StreamCallType.defaultType(),
        id: callId,
      );

      await call.getOrCreate(
        memberIds: [recipientId],
        ringing: true, // This triggers incoming call notification
      );

      _activeCall = call;
      notifyListeners();

      debugPrint('Call created successfully: $callId');
      return call;
    } catch (e) {
      debugPrint('Error creating call: $e');
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
      notifyListeners();

      debugPrint('Call declined successfully');
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
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    await endCall();
    await _client?.disconnect();
    _client = null;
    _incomingCallId = null;
    _incomingCallerName = null;
    notifyListeners();
    debugPrint('StreamVideoService disconnected');
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
