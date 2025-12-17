// screens/video_call/incoming_call_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import '../../services/video_call/stream_video_service.dart';

/// Incoming call screen for students
/// Shows caller name and accept/decline options
class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  late final StreamVideoService _videoService;
  StreamSubscription<CallState>? _callStateSubscription;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _videoService = context.read<StreamVideoService>();
    // Listen for call cancellation (caller hangs up before we answer)
    _videoService.addListener(_onServiceChanged);

    // Also listen directly to the incoming call's state for cancellation
    _setupCallStateListener();
  }

  void _setupCallStateListener() {
    final incomingCall = _videoService.incomingCall;
    if (incomingCall != null) {
      debugPrint('📞 [IncomingCallScreen] Setting up call state listener');
      _callStateSubscription = incomingCall.state.asStream().listen((
        callState,
      ) {
        final status = callState.status;
        debugPrint('📞 [IncomingCallScreen] Call state changed: $status');

        // Check if call was cancelled/ended by caller
        // Also check for Rejected status which happens when initiator cancels
        if (status.isDisconnected ||
            callState.endedAt != null ||
            status.isIdle ||
            status.toString().contains('Rejected')) {
          debugPrint(
            '📞 [IncomingCallScreen] Call cancelled by initiator - dismissing (status: $status)',
          );
          _dismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _callStateSubscription?.cancel();
    _videoService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    // If incoming call is cleared (caller cancelled), pop this screen
    if (_videoService.incomingCallId == null && mounted && !_isDismissing) {
      debugPrint(
        '🎥 [IncomingCallScreen] Call cancelled by caller - dismissing',
      );
      _dismiss();
    }
  }

  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;

    if (mounted) {
      try {
        context.pop();
      } catch (e) {
        debugPrint(
          '📞 [IncomingCallScreen] Error popping: $e - using fallback',
        );
        // Fallback: navigate to schedule if pop fails
        context.go('/schedule');
      }
    }
  }

  String get callId => widget.callId;
  String get callerName => widget.callerName;

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Camera and microphone permissions are required for video calls. '
          'Please enable them in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _acceptCall() async {
    debugPrint('🎥 [Incoming Call] Student accepting call...');

    // Request permissions immediately - this will trigger iOS system dialogs
    debugPrint(
      '🎥 [Incoming Call] Requesting camera and microphone permissions...',
    );
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
      debugPrint(
        '❌ [Incoming Call] Not all permissions granted - showing settings dialog',
      );
      if (mounted) {
        _showPermissionSettingsDialog();
      }
      return;
    }
    debugPrint('✅ [Incoming Call] All permissions granted');

    // Now accept the call (pass callId for background app scenarios)
    if (!mounted) return;
    final call = await _videoService.acceptIncomingCall(callId: callId);

    if (call != null && mounted) {
      // Navigate to video call screen
      // Pass callAlreadyJoined: true since we already accepted and joined in acceptIncomingCall()
      context.pushReplacementNamed(
        'video-call',
        pathParameters: {'callId': callId},
        queryParameters: {
          'recipientName': callerName,
          'callAlreadyJoined': 'true',
        },
      );
    }
  }

  void _declineCall() async {
    if (_isDismissing) return;
    _isDismissing = true;

    await _videoService.declineIncomingCall();

    if (mounted) {
      try {
        context.pop();
      } catch (e) {
        debugPrint(
          '📞 [IncomingCallScreen] Error popping after decline: $e - using fallback',
        );
        context.go('/schedule');
      }
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
                style: TextStyle(color: Colors.white70, fontSize: 16),
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
                          icon: const Icon(Icons.videocam, color: Colors.white),
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
