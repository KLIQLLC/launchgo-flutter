// screens/video_call/mentor_video_chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'base_video_chat_screen.dart';

/// Video chat screen for MENTORS (outgoing calls)
/// Mentor creates the call, joins immediately, and waits for student to connect
class MentorVideoChatScreen extends BaseVideoChatScreen {
  final String? recipientName;

  const MentorVideoChatScreen({
    super.key,
    required super.callId,
    this.recipientName,
  });

  @override
  State<MentorVideoChatScreen> createState() => _MentorVideoChatScreenState();
}

class _MentorVideoChatScreenState
    extends BaseVideoChatScreenState<MentorVideoChatScreen> {
  /// Timeout duration for unanswered calls (30 seconds)
  static const _callTimeoutDuration = Duration(seconds: 60);

  /// Timer for call timeout
  Timer? _callTimeoutTimer;

  /// Whether the student has answered the call
  bool _isStudentConnected = false;

  /// Whether the call was rejected/cancelled
  bool _isCallRejected = false;
  bool _sentFinalCallLog = false;

  void _sendCallLog(String event) {
    if (!mounted) return;
    final chatClient = StreamChat.of(context).client;
    if (chatClient.state.currentUser == null) return;

    final channelId = widget.callId.split('_').first;
    final channel = chatClient.channel('messaging', id: channelId);

    unawaited(
      channel.sendMessage(
        Message(
          type: 'system',
          text: '📞 Call $event',
          silent: true, // does not increase unread count, does not mark channel as unread
          extraData: const {'event_type': 'call'},
        ),
        skipPush: true, // do not send push notification
      ).then((_) {}, onError: (e) {
        debugPrint('[VC] ⚠️ [MentorVideoChatScreen] Error sending call $event: $e');
      }),
    );
  }

  @override
  String get displayName => widget.recipientName ?? 'Student';

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[VC] 📞 [MentorVideoChatScreen] recipientName: ${widget.recipientName}',
    );
    // Mentor always starts in "accepted" state - they initiated the call
    hasAcceptedCall = true;
  }

  @override
  void dispose() {
    _callTimeoutTimer?.cancel();
    super.dispose();
  }

  /// Start timeout timer - if student doesn't answer within 30 seconds, end call
  void _startCallTimeoutTimer() {
    debugPrint(
      '[VC] 📞 [MentorVideoChatScreen:_startCallTimeoutTimer] Starting ${_callTimeoutDuration.inSeconds}s timeout timer',
    );

    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(_callTimeoutDuration, () {
      if (mounted && !_isStudentConnected && !_isCallRejected && !isEnding) {
        debugPrint(
          '[VC] 📞 [MentorVideoChatScreen:_startCallTimeoutTimer] Timeout! No answer from student',
        );
        _handleCallTimeout();
      }
    });
  }

  /// Handle call timeout - student didn't answer
  void _handleCallTimeout() {
    debugPrint(
      '[VC] 📞 [MentorVideoChatScreen:_handleCallTimeout] Call timed out, ending call',
    );

    setState(() {
      _isCallRejected = true;
    });

    if (!_sentFinalCallLog) {
      _sentFinalCallLog = true;
      _sendCallLog('missed');
    }

    // End the call
    _cancelCall();
  }

  /// Cancel the outgoing call (mentor cancels before student answers)
  Future<void> _cancelCall() async {
    if (isEnding) return;

    debugPrint(
      '[VC] 📞 [MentorVideoChatScreen:_cancelCall] Cancelling outgoing call',
    );

    _callTimeoutTimer?.cancel();

    if (!_sentFinalCallLog) {
      _sentFinalCallLog = true;
      _sendCallLog('ended');
    }

    // IMPORTANT:
    // If mentor cancels while the student is still ringing (especially when student's phone is locked),
    // we MUST end the call on the server. Otherwise the call may keep ringing on Android because
    // the server never reports it as ended and no cancellation push arrives.
    //
    // `endCall()` in the base class only does `call.leave()` (client-side), so we call `call.end()`
    // first to mark the call as ended for all participants.
    if (!_isStudentConnected && call != null) {
      try {
        debugPrint(
          '[VC] 📞 [MentorVideoChatScreen:_cancelCall] Calling call.end() to end ringing for student...',
        );
        await call!.end();
        debugPrint(
          '[VC] 📞 [MentorVideoChatScreen:_cancelCall] call.end() completed',
        );
      } catch (e) {
        debugPrint(
          '[VC] ⚠️ [MentorVideoChatScreen:_cancelCall] call.end() failed: $e (continuing cleanup)',
        );
      }
    }

    // Base cleanup (leave + clear state + close screen)
    await endCall();
  }

  @override
  Future<void> endCall() async {
    if (!_sentFinalCallLog) {
      _sentFinalCallLog = true;
      _sendCallLog('ended');
    }
    await super.endCall();
  }

  @override
  Future<void> initializeCall() async {
    debugPrint('[VC] 📞 [MentorVideoChatScreen:initializeCall] >> ENTRY');

    try {
      // Setup the call
      final newCall = await setupCall();

      // Mentor joins immediately
      debugPrint(
        '[VC] 📞 [MentorVideoChatScreen:initializeCall] Joining call as mentor...',
      );
      await newCall.join();
      videoService.setActiveCall(newCall);
      debugPrint(
        '[VC] 📞 [MentorVideoChatScreen:initializeCall] Joined call successfully',
      );

      if (mounted) {
        setState(() {
          call = newCall;
          isLoading = false;
        });
      }

      // Setup state listener (includes reject detection)
      setupCallStateListener();

      // Start timeout timer - will cancel call if student doesn't answer in 30 seconds
      _startCallTimeoutTimer();

      debugPrint(
        '[VC] 📞 [MentorVideoChatScreen:initializeCall] << EXIT: Initialization complete',
      );
    } catch (e) {
      debugPrint(
        '[VC] ❌ [MentorVideoChatScreen:initializeCall] << EXIT: Error: $e',
      );
      if (mounted) {
        setState(() {
          error = 'Failed to connect to call: $e';
          isLoading = false;
        });
      }
    }
  }

  @override
  void setupCallStateListener() {
    debugPrint(
      '[VC] 📞 [MentorVideoChatScreen:setupCallStateListener] Setting up call state listener...',
    );

    callStateSubscription = call!.state.listen((state) {
      debugPrint(
        '[VC] 📞 [MentorVideoChatScreen:callStateListener] ========== CALL STATE CHANGED ==========',
      );
      debugPrint(
        '[VC] 📞 [MentorVideoChatScreen:callStateListener] Status: ${state.status}',
      );
      debugPrint(
        '[VC] 📞 [MentorVideoChatScreen:callStateListener] Total participants: ${state.callParticipants.length}',
      );

      for (var p in state.callParticipants) {
        debugPrint(
          '[VC] 📞 [MentorVideoChatScreen:callStateListener]   - Participant: userId=${p.userId}, name=${p.name}',
        );
      }

      if (mounted) {
        setState(() {
          callState = state;
        });
      }

      // Check if student has connected (2+ participants means student joined)
      if (state.callParticipants.length >= 2 && !_isStudentConnected) {
        debugPrint(
          '[VC] 📞 [MentorVideoChatScreen:callStateListener] Student connected! Stopping timeout timer.',
        );
        _isStudentConnected = true;
        hadMultipleParticipants = true;
        _callTimeoutTimer?.cancel();
      }

      // Handle call rejection (CallStatusDisconnected with reject reason)
      // or when call is ended by other party
      if (state.status is CallStatusDisconnected) {
        debugPrint(
          '[VC] 📞 [MentorVideoChatScreen:callStateListener] Call status is DISCONNECTED',
        );

        if (!_isStudentConnected && !_isCallRejected) {
          // Student rejected or call was cancelled before connection
          debugPrint(
            '[VC] 📞 [MentorVideoChatScreen:callStateListener] Call rejected/cancelled before connection',
          );
          if (!_sentFinalCallLog) {
            _sentFinalCallLog = true;
            _sendCallLog('declined');
          }
          _isCallRejected = true;
          _callTimeoutTimer?.cancel();
        }

        // Dismiss screen after delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !isEnding) {
            debugPrint(
              '[VC] 📞 [MentorVideoChatScreen:callStateListener] Navigating back after disconnect',
            );
            isEnding = true;
            videoService.clearActiveCall();
            navigateBack();
          }
        });
      }

      // Monitor participant count for 1-on-1 calls
      if (state.callParticipants.length >= 2) {
        if (!hadMultipleParticipants) {
          hadMultipleParticipants = true;
          debugPrint(
            '[VC] 📞 [MentorVideoChatScreen:callStateListener] Multiple participants (2+) detected for first time',
          );
        }
      }

      // End call if other person left (only after they were connected)
      if (!isEnding && hasAcceptedCall && hadMultipleParticipants) {
        if (state.callParticipants.length <= 1) {
          debugPrint(
            '[VC] 📞 [MentorVideoChatScreen:callStateListener] Participant count <= 1 (was 2+), other person left, ending call',
          );
          endCall();
          return;
        }

        final myUserId = authService.userInfo?.id.toString();
        final otherParticipants = state.callParticipants
            .where((p) => p.userId != myUserId)
            .toList();

        if (otherParticipants.isEmpty) {
          debugPrint(
            '[VC] 📞 [MentorVideoChatScreen:callStateListener] No other participants found, ending call',
          );
          endCall();
        }
      }
      debugPrint(
        '[VC] 📞 [MentorVideoChatScreen:callStateListener] ========== CALL STATE PROCESSING COMPLETE ==========',
      );
    });

    debugPrint(
      '[VC] 📞 [MentorVideoChatScreen:setupCallStateListener] Call state listener configured',
    );
  }

  @override
  Widget buildCallUI() {
    // If student hasn't connected yet, show "calling" UI with cancel button
    if (!_isStudentConnected && !_isCallRejected) {
      return _buildCallingUI();
    }

    // If call was rejected, show rejected UI briefly before navigating back
    if (_isCallRejected) {
      return _buildCallRejectedUI();
    }

    // Student connected - show active call UI (StreamCallContainer)
    return buildActiveCallUI();
  }

  /// Build UI for outgoing call (waiting for student to answer)
  Widget _buildCallingUI() {
    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar placeholder
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1A2332),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 32),

              // Student name
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              // Call status
              const Text(
                'Calling...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),

              const SizedBox(height: 64),

              // Cancel button
              Column(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.call_end, color: Colors.white),
                      onPressed: _cancelCall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build UI for rejected/timeout call
  Widget _buildCallRejectedUI() {
    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar placeholder
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1A2332),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.5),
                    width: 3,
                  ),
                ),
                child: const Icon(Icons.call_end, size: 60, color: Colors.red),
              ),

              const SizedBox(height: 32),

              // Student name
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              // Call status
              const Text(
                'Call not answered',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
