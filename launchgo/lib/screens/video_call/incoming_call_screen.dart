import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/video_call/stream_video_service.dart';

/// Incoming call screen for students
/// Shows caller name and accept/decline options
class IncomingCallScreen extends StatelessWidget {
  final String callId;
  final String callerName;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
  });

  void _showPermissionSettingsDialog(BuildContext context) {
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

  void _acceptCall(BuildContext context) async {
    debugPrint('🎥 [Incoming Call] Student accepting call...');

    // Request permissions immediately - this will trigger iOS system dialogs
    debugPrint('🎥 [Incoming Call] Requesting camera and microphone permissions...');
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    debugPrint('🎥 [Incoming Call] Permission request results:');
    debugPrint('   Camera: ${statuses[Permission.camera]}');
    debugPrint('   Microphone: ${statuses[Permission.microphone]}');

    // Check if all permissions are granted
    final allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      debugPrint('❌ [Incoming Call] Not all permissions granted - showing settings dialog');
      if (context.mounted) {
        _showPermissionSettingsDialog(context);
      }
      return;
    }
    debugPrint('✅ [Incoming Call] All permissions granted');

    // Now accept the call (pass callId for background app scenarios)
    if (!context.mounted) return;
    final videoService = context.read<StreamVideoService>();
    final call = await videoService.acceptIncomingCall(callId: callId);

    if (call != null && context.mounted) {
      // Navigate to video call screen
      context.pushReplacementNamed(
        'video-call',
        pathParameters: {'callId': callId},
        queryParameters: {'recipientName': callerName},
      );
    }
  }

  void _declineCall(BuildContext context) async {
    final videoService = context.read<StreamVideoService>();
    await videoService.declineIncomingCall();

    if (context.mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    color: Colors.white.withAlpha(51), // ~0.2 opacity
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
                callerName,
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
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 64),

              // Accept/Decline buttons
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
                          icon: const Icon(Icons.call_end, color: Colors.white),
                          onPressed: () => _declineCall(context),
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
                          icon: const Icon(Icons.videocam, color: Colors.white),
                          onPressed: () => _acceptCall(context),
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
