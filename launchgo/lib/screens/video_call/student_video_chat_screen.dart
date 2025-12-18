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

  /// Check if the mentor (other participant) has actually connected with video
  bool get _isMentorConnected {
    if (callState == null || call == null) return false;
    
    final myUserId = authService.userInfo?.id.toString();
    final participants = callState!.callParticipants;
    
    // Find other participants (not us)
    final otherParticipants = participants.where(
      (p) => p.userId != myUserId
    ).toList();
    
    debugPrint('[VC] 📞 [StudentVideoChatScreen:_isMentorConnected] My userId: $myUserId');
    debugPrint('[VC] 📞 [StudentVideoChatScreen:_isMentorConnected] Total participants: ${participants.length}');
    debugPrint('[VC] 📞 [StudentVideoChatScreen:_isMentorConnected] Other participants: ${otherParticipants.length}');
    
    for (var p in otherParticipants) {
      debugPrint('[VC] 📞 [StudentVideoChatScreen:_isMentorConnected]   - ${p.userId}: isOnline=${p.isOnline}, hasVideo=${p.isVideoEnabled}');
    }
    
    // Mentor is connected if there's at least one other participant who is online
    return otherParticipants.isNotEmpty && otherParticipants.any((p) => p.isOnline);
  }

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
    debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] callId: ${widget.callId}');
    debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] autoAccept: ${widget.autoAccept}');

    try {
      // IMPORTANT: First check if we already have an activeCall from the video service
      // This happens when call was accepted via CallKit/push (observeCoreRingingEvents)
      // The activeCall is ALREADY CONNECTED and we must use it, not create a new one
      final existingCall = videoService.activeCall;
      debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] Existing activeCall: $existingCall');
      debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] Existing activeCall id: ${existingCall?.id}');
      debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] Existing activeCall status: ${existingCall?.state.value.status}');

      if (existingCall != null && existingCall.id == widget.callId) {
        // Use the existing connected call - don't create a new one!
        debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] Using existing activeCall (already connected via CallKit)');
        debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] Call status: ${existingCall.state.value.status}');
        debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] Participants: ${existingCall.state.value.callParticipants.length}');
        
        if (mounted) {
          setState(() {
            call = existingCall;
            callState = existingCall.state.value;
            isLoading = false;
          });
        }

        // Setup state listener for ongoing updates
        setupCallStateListener();

        debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] << EXIT: Using existing activeCall');
        return;
      }

      // No existing activeCall - need to setup and accept the call ourselves
      debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] No existing activeCall, setting up new call...');
      final newCall = await setupCall();

      if (widget.autoAccept) {
        // User already tapped Answer on notification - auto-accept
        debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] autoAccept=true, accepting call...');
        await newCall.accept();
        videoService.setActiveCall(newCall);
        debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] Auto-accepted call successfully');
        debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] Call status after accept: ${newCall.state.value.status}');
      } else {
        // Wait for user to manually accept
        debugPrint('[VC] 📞 [StudentVideoChatScreen:initializeCall] Waiting for user to accept call');
      }

      if (mounted) {
        setState(() {
          call = newCall;
          // Set initial callState from the call's current state
          callState = newCall.state.value;
          isLoading = false;
        });
      }

      // Setup state listener for ongoing updates
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

    // If accepted but mentor hasn't connected yet, show waiting state
    if (!_isMentorConnected) {
      debugPrint('[VC] 📞 [StudentVideoChatScreen:buildCallUI] Call accepted but mentor not connected yet');
      return _buildWaitingForMentorUI();
    }

    // Otherwise show active call UI
    return buildActiveCallUI();
  }

  /// Build UI when waiting for mentor to connect
  Widget _buildWaitingForMentorUI() {
    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020817),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: endCall,
        ),
        title: Text(
          displayName,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          // End call button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              onPressed: endCall,
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing animation container
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A2332),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.5),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.white70,
                    ),
                  ),
                );
              },
              onEnd: () {
                // Trigger rebuild to restart animation
                if (mounted) setState(() {});
              },
            ),
            
            const SizedBox(height: 32),
            
            // Mentor name
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Waiting status
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.green,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Waiting for $displayName to connect...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Call accepted - connecting...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 64),
            
            // End call button
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
                    onPressed: endCall,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'End Call',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
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
            // Update callState after accepting
            callState = call!.state.value;
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
