// screens/video_call/student_video_chat_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'base_video_chat_screen.dart';

/// Video chat screen for STUDENTS (incoming calls)
/// Student receives the call and can accept/decline
/// If autoAccept=true, the call is accepted automatically (user tapped Answer on notification)
class StudentVideoChatScreen extends BaseVideoChatScreen {
  final String? callerName;
  final bool autoAccept;

  const StudentVideoChatScreen({
    super.key,
    required super.callId,
    this.callerName,
    this.autoAccept = false,
  });

  @override
  State<StudentVideoChatScreen> createState() => _StudentVideoChatScreenState();
}

class _StudentVideoChatScreenState
    extends BaseVideoChatScreenState<StudentVideoChatScreen> {
  bool _isAccepting = false;
  bool _isCallCancelled = false;

  @override
  String get displayName => widget.callerName ?? 'Mentor';

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[VC] 📞 [StudentVideoChatScreen] callerName: ${widget.callerName}',
    );
    debugPrint(
      '[VC] 📞 [StudentVideoChatScreen] autoAccept: ${widget.autoAccept}',
    );

    // If autoAccept, mark as accepted
    if (widget.autoAccept) {
      hasAcceptedCall = true;
    }

    // Listen to videoService for call cancellation
    // When mentor cancels, incomingCallId becomes null
    videoService.addListener(_onVideoServiceChanged);
  }

  @override
  void dispose() {
    videoService.removeListener(_onVideoServiceChanged);
    super.dispose();
  }

  /// Called when videoService state changes
  void _onVideoServiceChanged() {
    debugPrint(
      '[VC] 📞 [StudentVideoChatScreen:_onVideoServiceChanged] incomingCallId: ${videoService.incomingCallId}, hasActiveCall: ${videoService.hasActiveCall}, hasAcceptedCall: $hasAcceptedCall, _isCallCancelled: $_isCallCancelled',
    );

    // If call was cancelled by mentor:
    // - incomingCallId is null (no longer ringing)
    // - hasActiveCall is false (not accepted - if accepted, activeCall would be set)
    // - we haven't already handled it
    if (videoService.incomingCallId == null &&
        !videoService.hasActiveCall &&
        !hasAcceptedCall &&
        !_isCallCancelled &&
        !isEnding) {
      debugPrint(
        '[VC] 📞 [StudentVideoChatScreen:_onVideoServiceChanged] Call cancelled by mentor - closing screen',
      );
      _handleCallCancelled();
    }
  }

  @override
  Future<void> initializeCall() async {
    debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] >> ENTRY');

    try {
      Call newCall;

      if (widget.autoAccept) {
        // User already tapped Answer on notification (CallKit/push)
        // On iOS: The call is ALREADY JOINED by Stream SDK via observeCoreRingingEvents
        // On Android from terminated state: The call is ALREADY JOINED via consumeAndAcceptActiveCall
        // We must use the existing active call from the service, NOT create a new reference
        debugPrint(
          '[VC] 📞 [StudentVideoChatScreen:initializeCall] autoAccept=true',
        );
        debugPrint(
          '[VC] 📞 [StudentVideoChatScreen:initializeCall] Checking for active call from service...',
        );

        final existingCall = videoService.activeCall;
        if (existingCall != null && existingCall.id == widget.callId) {
          // Use the already-joined call from the service
          debugPrint(
            '[VC] 📞 [StudentVideoChatScreen:initializeCall] Using existing active call from service (already joined)',
          );
          newCall = existingCall;
        } else {
          // Fallback: Call might not be in service yet, setup and accept
          debugPrint(
            '[VC] 📞 [StudentVideoChatScreen:initializeCall] No active call in service, setting up new call...',
          );
          newCall = await setupCall();
          debugPrint(
            '[VC] 📞 [StudentVideoChatScreen:initializeCall] Accepting call...',
          );
          await newCall.accept();
          videoService.setActiveCall(newCall);
          debugPrint(
            '[VC] 📞 [StudentVideoChatScreen:initializeCall] Call accepted and set as active',
          );
        }
      } else {
        // Manual accept flow - setup call and wait for user to accept
        debugPrint(
          '[VC] 📞 [StudentVideoChatScreen:initializeCall] Waiting for user to accept call',
        );
        newCall = await setupCall();
      }

      if (mounted) {
        setState(() {
          call = newCall;
          isLoading = false;
        });
      }

      // Setup state listener
      setupCallStateListener();

      debugPrint(
        '[VC] 📞 [StudentVideoChatScreen:initializeCall] << EXIT: Initialization complete',
      );
    } catch (e) {
      debugPrint(
        '[VC] ❌ [StudentVideoChatScreen:initializeCall] << EXIT: Error: $e',
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
      '[VC] 📞 [StudentVideoChatScreen:setupCallStateListener] Setting up call state listener...',
    );

    callStateSubscription = call!.state.listen((state) {
      debugPrint(
        '[VC] 📞 [StudentVideoChatScreen:callStateListener] ========== CALL STATE CHANGED ==========',
      );
      debugPrint(
        '[VC] 📞 [StudentVideoChatScreen:callStateListener] Status: ${state.status}',
      );
      debugPrint(
        '[VC] 📞 [StudentVideoChatScreen:callStateListener] hasAcceptedCall: $hasAcceptedCall',
      );
      debugPrint(
        '[VC] 📞 [StudentVideoChatScreen:callStateListener] Total participants: ${state.callParticipants.length}',
      );

      if (mounted) {
        setState(() {
          callState = state;
        });
      }

      // Handle call cancelled by mentor (before student accepted)
      if (state.status is CallStatusDisconnected &&
          !hasAcceptedCall &&
          !_isCallCancelled) {
        debugPrint(
          '[VC] 📞 [StudentVideoChatScreen:callStateListener] Call cancelled by mentor before acceptance',
        );
        _handleCallCancelled();
        return;
      }

      // Handle call disconnected after acceptance (normal end)
      if (state.status is CallStatusDisconnected && hasAcceptedCall) {
        debugPrint(
          '[VC] 📞 [StudentVideoChatScreen:callStateListener] Call ended after acceptance',
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !isEnding) {
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
            '[VC] 📞 [StudentVideoChatScreen:callStateListener] Multiple participants (2+) detected',
          );
        }
      }

      // End call if other person left (only after both were connected)
      if (!isEnding && hasAcceptedCall && hadMultipleParticipants) {
        if (state.callParticipants.length <= 1) {
          debugPrint(
            '[VC] 📞 [StudentVideoChatScreen:callStateListener] Other participant left, ending call',
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
            '[VC] 📞 [StudentVideoChatScreen:callStateListener] No other participants found, ending call',
          );
          endCall();
        }
      }
      debugPrint(
        '[VC] 📞 [StudentVideoChatScreen:callStateListener] ========== CALL STATE PROCESSING COMPLETE ==========',
      );
    });

    debugPrint(
      '[VC] 📞 [StudentVideoChatScreen:setupCallStateListener] Call state listener configured',
    );
  }

  /// Handle call cancelled by mentor
  void _handleCallCancelled() {
    debugPrint(
      '[VC] 📞 [StudentVideoChatScreen:_handleCallCancelled] Mentor cancelled the call',
    );

    setState(() {
      _isCallCancelled = true;
    });

    // End CallKit notification on Android
    if (Platform.isAndroid) {
      debugPrint(
        '[VC] 📞 [StudentVideoChatScreen:_handleCallCancelled] Ending CallKit notification',
      );
      FlutterCallkitIncoming.endAllCalls().catchError((e) {
        debugPrint(
          '[VC] ⚠️ [StudentVideoChatScreen:_handleCallCancelled] Error ending CallKit: $e',
        );
      });
    }

    videoService.clearActiveCall();

    // Navigate back after showing cancelled UI briefly
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !isEnding) {
        isEnding = true;
        navigateBack();
      }
    });
  }

  @override
  Widget buildCallUI() {
    // If call was cancelled by mentor, show cancelled UI
    if (_isCallCancelled) {
      return _buildCallCancelledUI();
    }

    // If not yet accepted, show incoming call UI
    if (!hasAcceptedCall) {
      return _buildIncomingCallUI();
    }

    // Otherwise show active call UI
    return buildActiveCallUI();
  }

  /// Build UI for cancelled call (mentor cancelled before student accepted)
  Widget _buildCallCancelledUI() {
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

              // Caller name
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
                'Call cancelled',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Accept the incoming call
  Future<void> _acceptCall() async {
    debugPrint('[VC] 📞 [StudentVideoChatScreen:_acceptCall] >> ENTRY');

    setState(() {
      _isAccepting = true;
    });

    try {
      // Request permissions
      debugPrint(
        '[VC] 📞 [StudentVideoChatScreen:_acceptCall] Requesting permissions...',
      );
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      debugPrint(
        '[VC] 📞 [StudentVideoChatScreen:_acceptCall] Camera: ${statuses[Permission.camera]}',
      );
      debugPrint(
        '[VC] 📞 [StudentVideoChatScreen:_acceptCall] Microphone: ${statuses[Permission.microphone]}',
      );

      final allGranted = statuses.values.every((status) => status.isGranted);

      if (!allGranted) {
        debugPrint(
          '[VC] ❌ [StudentVideoChatScreen:_acceptCall] Permissions NOT granted',
        );
        if (mounted) {
          _showPermissionSettingsDialog();
        }
        setState(() {
          _isAccepting = false;
        });
        return;
      }

      // Accept the call
      if (call != null) {
        debugPrint(
          '[VC] 📞 [StudentVideoChatScreen:_acceptCall] Calling accept()...',
        );
        await call!.accept();
        debugPrint(
          '[VC] 📞 [StudentVideoChatScreen:_acceptCall] Call accepted successfully',
        );

        videoService.setActiveCall(call!);

        if (mounted) {
          setState(() {
            _isAccepting = false;
            hasAcceptedCall = true;
          });
        }
      }
    } catch (e) {
      debugPrint('[VC] ❌ [StudentVideoChatScreen:_acceptCall] Error: $e');
      if (mounted) {
        setState(() {
          error = 'Failed to accept call: $e';
          _isAccepting = false;
        });
      }
    }
  }

  /// Decline the incoming call
  Future<void> _declineCall() async {
    debugPrint('[VC] 📞 [StudentVideoChatScreen:_declineCall] Declining call');

    try {
      if (call != null) {
        await call!.reject();
        debugPrint(
          '[VC] 📞 [StudentVideoChatScreen:_declineCall] Call rejected successfully',
        );
      }

      // End CallKit notification on Android
      if (Platform.isAndroid) {
        debugPrint(
          '[VC] 📞 [StudentVideoChatScreen:_declineCall] Ending CallKit notification',
        );
        await FlutterCallkitIncoming.endAllCalls();
      }

      videoService.clearActiveCall();
      navigateBack();
    } catch (e) {
      debugPrint('[VC] ❌ [StudentVideoChatScreen:_declineCall] Error: $e');

      // Still try to end CallKit on error
      if (Platform.isAndroid) {
        FlutterCallkitIncoming.endAllCalls().catchError((err) {
          debugPrint(
            '[VC] ⚠️ [StudentVideoChatScreen:_declineCall] Error ending CallKit: $err',
          );
        });
      }

      videoService.clearActiveCall();
      navigateBack();
    }
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Camera and microphone permissions are required for video calls. '
          'Please enable them in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingCallUI() {
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

              // Caller name
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
                'Incoming video call',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),

              const SizedBox(height: 64),

              // Accept/Decline buttons
              if (_isAccepting)
                const CircularProgressIndicator(color: Colors.white)
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Decline button
                    Column(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 40,
                            icon: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                            ),
                            onPressed: _declineCall,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Decline',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),

                    const SizedBox(width: 80),

                    // Accept button
                    Column(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 40,
                            icon: const Icon(
                              Icons.videocam,
                              color: Colors.white,
                            ),
                            onPressed: _acceptCall,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Accept',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
