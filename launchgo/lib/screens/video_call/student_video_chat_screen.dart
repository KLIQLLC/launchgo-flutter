import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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

class _StudentVideoChatScreenState extends BaseVideoChatScreenState<StudentVideoChatScreen> {
  bool _isAccepting = false;

  @override
  String get displayName => widget.callerName ?? 'Mentor';

  @override
  void initState() {
    super.initState();
    debugPrint('[VC] 📞 [StudentVideoChatScreen] callerName: ${widget.callerName}');
    debugPrint('[VC] 📞 [StudentVideoChatScreen] autoAccept: ${widget.autoAccept}');

    // If autoAccept, mark as accepted
    if (widget.autoAccept) {
      hasAcceptedCall = true;
    }
  }

  @override
  Future<void> initializeCall() async {
    debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] >> ENTRY');

    try {
      // Setup the call
      final newCall = await setupCall();

      if (widget.autoAccept) {
        // User already tapped Answer on notification - auto-accept
        debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] autoAccept=true, accepting call automatically...');
        await newCall.accept();
        videoService.setActiveCall(newCall);
        debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] Auto-accepted call successfully');
      } else {
        // Wait for user to manually accept
        debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] Waiting for user to accept call');
      }

      if (mounted) {
        setState(() {
          call = newCall;
          isLoading = false;
        });
      }

      // Setup state listener
      setupCallStateListener();

      debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] << EXIT: Initialization complete');
    } catch (e) {
      debugPrint('[VC] ❌ [StudentVideoChatScreen:initializeCall] << EXIT: Error: $e');
      if (mounted) {
        setState(() {
          error = 'Failed to connect to call: $e';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget buildCallUI() {
    // If not yet accepted, show incoming call UI
    if (!hasAcceptedCall) {
      return _buildIncomingCallUI();
    }

    // Otherwise show active call UI
    return buildActiveCallUI();
  }

  /// Accept the incoming call
  Future<void> _acceptCall() async {
    debugPrint('[VC] 📞 [StudentVideoChatScreen:_acceptCall] >> ENTRY');

    setState(() {
      _isAccepting = true;
    });

    try {
      // Request permissions
      debugPrint('[VC] 📞 [StudentVideoChatScreen:_acceptCall] Requesting permissions...');
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      debugPrint('[VC] 📞 [StudentVideoChatScreen:_acceptCall] Camera: ${statuses[Permission.camera]}');
      debugPrint('[VC] 📞 [StudentVideoChatScreen:_acceptCall] Microphone: ${statuses[Permission.microphone]}');

      final allGranted = statuses.values.every((status) => status.isGranted);

      if (!allGranted) {
        debugPrint('[VC] ❌ [StudentVideoChatScreen:_acceptCall] Permissions NOT granted');
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
        debugPrint('[VC] 📞 [StudentVideoChatScreen:_acceptCall] Calling accept()...');
        await call!.accept();
        debugPrint('[VC] 📞 [StudentVideoChatScreen:_acceptCall] Call accepted successfully');

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
        debugPrint('[VC] 📞 [StudentVideoChatScreen:_declineCall] Call rejected successfully');
      }

      videoService.clearActiveCall();
      navigateBack();
    } catch (e) {
      debugPrint('[VC] ❌ [StudentVideoChatScreen:_declineCall] Error: $e');
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
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
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
