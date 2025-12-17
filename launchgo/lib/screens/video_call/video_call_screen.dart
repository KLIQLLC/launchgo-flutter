// screens/video_call/video_call_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:go_router/go_router.dart';
import '../../services/video_call/stream_video_service.dart';

/// Video call screen showing active call with controls
/// Used by both mentors and students during an active call
class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String recipientName;
  final bool
  callAlreadyJoined; // True if call was joined via CallKit/ringing events

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.recipientName,
    this.callAlreadyJoined = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final StreamVideoService _videoService;
  Call? _call;
  bool _isLoading = true;
  String? _error;
  bool _isNavigatingAway =
      false; // Prevent duplicate navigation and endCall in dispose

  @override
  void initState() {
    super.initState();
    debugPrint(
      '🎥 [VideoCallScreen] initState called - callId: ${widget.callId}, recipientName: ${widget.recipientName}, callAlreadyJoined: ${widget.callAlreadyJoined}',
    );
    _videoService = context.read<StreamVideoService>();
    WakelockPlus.enable(); // Keep screen on during call

    // Listen to service for remote call end detection
    _videoService.addListener(_onVideoServiceChanged);

    _initializeCall();
  }

  /// Called when video service state changes - detect if call ended by remote party
  void _onVideoServiceChanged() {
    // Only navigate away if:
    // 1. We had a local _call object set
    // 2. The service no longer has an active call
    // 3. We're not already navigating away
    // 4. The call was actually connected (not just initializing)
    if (_call != null &&
        !_videoService.hasActiveCall &&
        !_isNavigatingAway &&
        !_isLoading) {
      // Don't navigate away during initial loading
      // Additional check: make sure the call state is actually disconnected
      final callState = _call!.state.valueOrNull;
      final isDisconnected = callState?.status.isDisconnected ?? false;
      final hasEnded = callState?.endedAt != null;

      if (isDisconnected || hasEnded) {
        debugPrint(
          '🎥 [VideoCallScreen] Call ended (disconnected: $isDisconnected, hasEnded: $hasEnded) - navigating away',
        );
        _navigateAway();
      } else {
        debugPrint(
          '🎥 [VideoCallScreen] Service has no active call but call state not disconnected - waiting',
        );
      }
    }
  }

  Future<void> _initializeCall() async {
    debugPrint(
      '🎥 [VideoCallScreen] _initializeCall starting for callId: ${widget.callId}',
    );

    // First check if we have an activeCall from the service (set during createCall or acceptIncomingCall)
    final existingCall = _videoService.activeCall;
    debugPrint(
      '🎥 [VideoCallScreen] Existing activeCall from service: $existingCall',
    );

    if (existingCall != null && existingCall.id == widget.callId) {
      debugPrint(
        '🎥 [VideoCallScreen] Using existing activeCall: ${existingCall.id}',
      );
      if (mounted) {
        setState(() {
          _call = existingCall;
          _isLoading = false;
        });
      }
      return;
    }

    // If no activeCall, try to get the call from the client using the callId
    debugPrint(
      '🎥 [VideoCallScreen] No matching activeCall, fetching call by ID: ${widget.callId}',
    );
    final client = _videoService.client;

    if (client == null) {
      debugPrint('❌ [VideoCallScreen] Client is null - cannot fetch call');
      if (mounted) {
        setState(() {
          _error = 'Video client not initialized';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final call = client.makeCall(
        callType: StreamCallType.defaultType(),
        id: widget.callId,
      );

      // Get or create ensures we have the call state
      await call.getOrCreate();
      debugPrint('🎥 [VideoCallScreen] Call fetched successfully: ${call.id}');

      // If callAlreadyJoined is true but we had to fetch the call (activeCall was null),
      // it means there was a race condition - we need to join the call now
      if (widget.callAlreadyJoined) {
        debugPrint(
          '🎥 [VideoCallScreen] callAlreadyJoined=true but had to fetch call - joining now',
        );
        // Ensure client WebSocket is connected (app may have just resumed from background)
        try {
          await client.connect();
        } catch (e) {
          debugPrint(
            '⚠️ [VideoCallScreen] client.connect() failed/ignored: $e',
          );
        }

        final callState = call.state.value;
        // Only join if not already connected
        if (!callState.status.isConnected && !callState.status.isReconnecting) {
          debugPrint(
            '🎥 [VideoCallScreen] Call not connected, calling accept() and join()...',
          );
          try {
            await call.accept();
            debugPrint('🎥 [VideoCallScreen] Call accepted');
          } catch (e) {
            debugPrint(
              '⚠️ [VideoCallScreen] Accept failed (might already be accepted): $e',
            );
          }
          await call.join();
          debugPrint('🎥 [VideoCallScreen] Call joined successfully');
        } else {
          debugPrint(
            '🎥 [VideoCallScreen] Call already connected: ${callState.status}',
          );
        }
      }

      if (mounted) {
        setState(() {
          _call = call;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [VideoCallScreen] Error fetching/joining call: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to connect to call';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoService.removeListener(_onVideoServiceChanged);
    WakelockPlus.disable();
    // End call when screen is disposed (user backs out or screen is closed)
    // Skip if already navigating away (call already ended by remote party)
    if (!_isNavigatingAway) {
      _videoService.endCall(); // Don't await in dispose
    }
    super.dispose();
  }

  /// Safely navigate away from the call screen
  void _navigateAway() {
    if (_isNavigatingAway) return;
    _isNavigatingAway = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        // Simply pop back to previous screen
        context.pop();
      } catch (e) {
        // Safety fallback if pop fails (shouldn't happen in normal flow)
        debugPrint('🎥 [VideoCallScreen] Pop failed, going to schedule: $e');
        GoRouter.of(context).go('/schedule');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '🎥 [VideoCallScreen] build() called - _call: $_call, _isLoading: $_isLoading, _error: $_error',
    );

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF020817),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Connecting...',
                style: TextStyle(
                  color: Colors.white.withAlpha(179), // ~0.7 opacity
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _call == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF020817),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Failed to connect',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _navigateAway,
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    debugPrint(
      '🎥 [VideoCallScreen] Call ready - callAlreadyJoined: ${widget.callAlreadyJoined}',
    );

    // If call was already joined (via CallKit/ringing events), use StreamCallContent directly
    // to avoid StreamCallContainer calling join() again
    if (widget.callAlreadyJoined) {
      debugPrint(
        '🎥 [VideoCallScreen] Using StreamCallContent (call already joined)',
      );
      // Use StreamBuilder to listen to call state changes and rebuild UI accordingly
      // This ensures the video streams update when participants join/leave
      return StreamBuilder<CallState>(
        stream: _call!.state.asStream(),
        initialData: _call!.state.value,
        builder: (context, snapshot) {
          final callState = snapshot.data ?? _call!.state.value;
          debugPrint(
            '🎥 [VideoCallScreen] StreamBuilder rebuild - status: ${callState.status}',
          );

          // Check if call has ended (other party ended the call)
          if (callState.status.isDisconnected && !_isNavigatingAway) {
            debugPrint(
              '🎥 [VideoCallScreen] Call disconnected - navigating away',
            );
            _navigateAway();
            return const Scaffold(
              backgroundColor: Color(0xFF020817),
              body: Center(
                child: Text(
                  'Call ended',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              ),
            );
          }

          return StreamCallContent(
            call: _call!,
            callState: callState,
            onBackPressed: () {
              _videoService.endCall();
              _navigateAway();
            },
            onLeaveCallTap: () {
              _videoService.endCall();
              _navigateAway();
            },
          );
        },
      );
    }

    debugPrint(
      '🎥 [VideoCallScreen] Using StreamCallContainer for call ${_call!.id}',
    );

    // Use StreamCallContainer with default UI (following Stream's official sample pattern)
    // This handles call join, participant management, UI controls automatically
    return StreamCallContainer(
      call: _call!,
      onBackPressed: () {
        _videoService.endCall();
        _navigateAway();
      },
      // Important: Wire onLeaveCallTap to use endCall() which terminates for ALL participants
      // Default Stream behavior uses leave() which only removes local user
      onLeaveCallTap: () {
        _videoService.endCall();
        _navigateAway();
      },
    );
  }
}
