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

  @override
  void initState() {
    super.initState();
    debugPrint('🎥 [VideoCallScreen] initState called - callId: ${widget.callId}, recipientName: ${widget.recipientName}');
    _videoService = context.read<StreamVideoService>();
    debugPrint('🎥 [VideoCallScreen] videoService.activeCall: ${_videoService.activeCall}');
    debugPrint('🎥 [VideoCallScreen] videoService.hasActiveCall: ${_videoService.hasActiveCall}');
    WakelockPlus.enable(); // Keep screen on during call
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    // End call when screen is disposed (user backs out or screen is closed)
    _videoService.endCall(); // Don't await in dispose
    super.dispose();
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

    debugPrint('🎥 [VideoCallScreen] activeCall found - using StreamCallContainer for call ${call.id}');

    // Use StreamCallContainer with default UI (following Stream's official sample pattern)
    // This handles call join, participant management, UI controls automatically
    return StreamCallContainer(
      call: call,
      onBackPressed: () {
        _videoService.endCall();
        if (mounted) {
          context.pop();
        }
      },
    );
  }
}
