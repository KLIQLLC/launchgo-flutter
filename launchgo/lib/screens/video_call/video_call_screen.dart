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

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.recipientName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final StreamVideoService _videoService;
  DateTime? _joinedAt;

  @override
  void initState() {
    super.initState();
    debugPrint('🎥 [VideoCallScreen] initState called - callId: ${widget.callId}, recipientName: ${widget.recipientName}');
    _videoService = context.read<StreamVideoService>();
    debugPrint('🎥 [VideoCallScreen] videoService.activeCall: ${_videoService.activeCall}');
    debugPrint('🎥 [VideoCallScreen] videoService.hasActiveCall: ${_videoService.hasActiveCall}');
    _joinedAt = DateTime.now();
    WakelockPlus.enable(); // Keep screen on during call
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    // End call when screen is disposed (user backs out or screen is closed)
    _videoService.endCall(); // Don't await in dispose
    super.dispose();
  }

  void _endCall() async {
    await _videoService.endCall();
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoService = context.watch<StreamVideoService>();
    final call = videoService.activeCall;

    debugPrint('🎥 [VideoCallScreen] build() called - call: $call, hasActiveCall: ${videoService.hasActiveCall}');

    if (call == null) {
      debugPrint('🎥 [VideoCallScreen] activeCall is NULL - showing Connecting screen');
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

    debugPrint('🎥 [VideoCallScreen] activeCall found - showing video UI for call ${call.id}');

    return StreamCallContainer(
      call: call,
      callContentBuilder: (
        BuildContext context,
        Call call,
        CallState callState,
      ) {
        // Debug: Log call state and participants
        debugPrint('🎥 [VideoCallScreen] callContentBuilder called');
        debugPrint('🎥 [VideoCallScreen] Call status: ${callState.status}');
        debugPrint('🎥 [VideoCallScreen] Participants count: ${callState.callParticipants.length}');
        debugPrint('🎥 [VideoCallScreen] Participants: ${callState.callParticipants.map((p) => '${p.userId} (local: ${p.isLocal}, video: ${p.isVideoEnabled}, audio: ${p.isAudioEnabled})').join(', ')}');
        debugPrint('🎥 [VideoCallScreen] Local participant: ${callState.localParticipant?.userId}');

        // Check for error conditions
        final isDisconnected = callState.status.toString().contains('Disconnected');
        final hasLocalParticipant = callState.localParticipant != null;
        final waitingTime = _joinedAt != null ? DateTime.now().difference(_joinedAt!) : Duration.zero;
        final isWaitingTooLong = waitingTime > const Duration(seconds: 30);

        // Show error if disconnected without ever connecting
        if (isDisconnected && !hasLocalParticipant) {
          debugPrint('❌ [VideoCallScreen] Call disconnected without local participant');
          return _buildErrorScreen('Call Failed', 'The call was declined or timed out');
        }

        // Show error if waiting too long for other participant
        if (hasLocalParticipant && callState.callParticipants.length < 2 && isWaitingTooLong) {
          debugPrint('❌ [VideoCallScreen] Waiting too long for other participant (${waitingTime.inSeconds}s)');
          return _buildErrorScreen('Connection Timeout', 'Unable to connect to the other participant');
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Main video participants grid
              Positioned.fill(
                child: StreamCallParticipants(
                  call: call,
                  participants: callState.callParticipants,
                ),
              ),

              // Top bar with name and call info
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(179), // ~0.7 opacity
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.recipientName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCallStatus(callState),
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withAlpha(179), // ~0.7 opacity
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mute/unmute microphone button
                        _ControlButton(
                          icon: Icons.mic_off,
                          activeIcon: Icons.mic,
                          onPressed: () async {
                            final isAudioEnabled = callState.localParticipant?.isAudioEnabled ?? false;
                            await call.setMicrophoneEnabled(enabled: !isAudioEnabled);
                          },
                          isActive: callState.localParticipant?.isAudioEnabled ?? false,
                        ),

                        // End call button
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 36,
                            icon: const Icon(Icons.call_end, color: Colors.white),
                            onPressed: _endCall,
                          ),
                        ),

                        // Toggle camera button
                        _ControlButton(
                          icon: Icons.videocam_off,
                          activeIcon: Icons.videocam,
                          onPressed: () async {
                            final isVideoEnabled = callState.localParticipant?.isVideoEnabled ?? false;
                            await call.setCameraEnabled(enabled: !isVideoEnabled);
                          },
                          isActive: callState.localParticipant?.isVideoEnabled ?? false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getCallStatus(CallState callState) {
    final participants = callState.callParticipants;
    if (participants.length < 2) {
      return 'Waiting for other participant...';
    }
    return 'Connected';
  }

  Widget _buildErrorScreen(String title, String message) {
    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withAlpha(179),
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  _videoService.endCall();
                  if (mounted) {
                    context.pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(26),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom control button widget
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final VoidCallback onPressed;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.activeIcon,
    required this.onPressed,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withAlpha(51)  // ~0.2 opacity
            : Colors.white.withAlpha(26), // ~0.1 opacity
        shape: BoxShape.circle,
      ),
      child: IconButton(
        iconSize: 28,
        icon: Icon(
          isActive ? activeIcon : icon,
          color: Colors.white,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
