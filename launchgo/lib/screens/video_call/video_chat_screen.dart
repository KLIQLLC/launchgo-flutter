import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/video_call/stream_video_service.dart';
import '../../services/auth_service.dart';

/// Single screen for ALL video call states
/// Handles: incoming calls, outgoing calls, active calls, and errors
/// Used by both mentors (outgoing) and students (incoming)
class VideoChatScreen extends StatefulWidget {
  final String callId;
  final String? callerName;  // Caller name for students (incoming)
  final String? recipientName;  // Recipient name for mentors (outgoing)
  final bool isIncoming;  // True if student receiving a call
  final bool callAlreadyJoined;  // True if call accepted via CallKit/push
  final bool autoAccept;  // True if user already tapped Answer on notification

  const VideoChatScreen({
    super.key,
    required this.callId,
    this.callerName,
    this.recipientName,
    this.isIncoming = false,
    this.callAlreadyJoined = false,
    this.autoAccept = false,
  });

  @override
  State<VideoChatScreen> createState() => _VideoChatScreenState();
}

class _VideoChatScreenState extends State<VideoChatScreen> {
  late final StreamVideoService _videoService;
  late final AuthService _authService;
  Call? _call;
  StreamSubscription<CallState>? _callStateSubscription;
  bool _isLoading = true;
  bool _isAccepting = false;
  bool _hasAcceptedCall = false;  // Track if student has accepted the call
  bool _isEnding = false;  // Prevent recursive call ending
  bool _hadMultipleParticipants = false;  // Track if we ever had 2+ participants
  String? _error;
  CallState? _callState;

  @override
  void initState() {
    super.initState();
    debugPrint('[VIDEO_CALL] VideoChatScreen.initState()');
    debugPrint('[VIDEO_CALL]   callId: ${widget.callId}');
    debugPrint('[VIDEO_CALL]   isIncoming: ${widget.isIncoming}');
    debugPrint('[VIDEO_CALL]   callAlreadyJoined: ${widget.callAlreadyJoined}');
    debugPrint('[VIDEO_CALL]   autoAccept: ${widget.autoAccept}');
    debugPrint('[VIDEO_CALL]   callerName: ${widget.callerName}');
    debugPrint('[VIDEO_CALL]   recipientName: ${widget.recipientName}');

    _videoService = context.read<StreamVideoService>();
    _authService = context.read<AuthService>();
    WakelockPlus.enable(); // Keep screen on during call

    // If call was already joined via CallKit, mark as accepted
    if (widget.callAlreadyJoined || widget.autoAccept) {
      _hasAcceptedCall = true;
    }

    _initializeCall();
  }

  Future<void> _initializeCall() async {
    debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] >> ENTRY');
    debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Widget callId: ${widget.callId}');
    debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Widget isIncoming: ${widget.isIncoming}');
    debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Widget callAlreadyJoined: ${widget.callAlreadyJoined}');
    debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Widget callerName: ${widget.callerName}');
    debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Widget recipientName: ${widget.recipientName}');

    final userRole = _authService.userInfo?.role.toString() ?? 'unknown';
    debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Current user role: $userRole');

    try {
      // Get call from service
      final client = _videoService.client;
      debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Video client exists: ${client != null}');

      if (client == null) {
        throw Exception('Video client not initialized');
      }

      // Create call reference
      debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Creating call reference for callId: ${widget.callId}');
      final call = client.makeCall(
        callType: StreamCallType.defaultType(),
        id: widget.callId,
      );
      debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Call reference created');

      // Get or create the call
      // Note: ringing is handled server-side when mentor creates the call
      final isOutgoing = !widget.isIncoming && !widget.autoAccept;
      debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] isOutgoing: $isOutgoing, isIncoming: ${widget.isIncoming}, autoAccept: ${widget.autoAccept}');
      debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Fetching call with getOrCreate()...');
      await call.getOrCreate();
      debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Call fetched successfully: ${call.id}');

      // For outgoing calls (mentors), automatically join the call
      if (isOutgoing) {
        debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] OUTGOING call (mentor) - joining automatically');
        await call.join();
        _videoService.setActiveCall(call);
        debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Joined outgoing call successfully');
      } else if (widget.autoAccept) {
        // User already tapped Answer on notification - auto-accept the call
        debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] INCOMING call with autoAccept=true - accepting automatically');
        await call.accept();
        _videoService.setActiveCall(call);
        debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Auto-accepted incoming call successfully');
      } else if (widget.isIncoming) {
        debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] INCOMING call (student) - NOT auto-joining, waiting for accept');
      }

      if (mounted) {
        debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Widget still mounted, updating state');
        setState(() {
          _call = call;
          _isLoading = false;
          // For outgoing calls or autoAccept, mark as accepted immediately
          if (!widget.isIncoming || widget.autoAccept) {
            _hasAcceptedCall = true;
            debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Marked call as accepted (outgoing or autoAccept)');
          }
        });
        debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] State updated, isLoading=false');
      } else {
        debugPrint('[VC] ⚠️ [VideoChatScreen:_initializeCall] Widget NOT mounted, skipping state update');
      }

      // Listen to call state changes
      debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Setting up call state listener...');
      _callStateSubscription = _call!.state.listen((state) {
        debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] ========== CALL STATE CHANGED ==========');
        debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] Status: ${state.status}');
        debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] Total participants: ${state.callParticipants.length}');
        debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] My user ID: ${_authService.userInfo?.id.toString()}');

        // Log all participants
        for (var p in state.callParticipants) {
          debugPrint('[VC] 📞 [VideoChatScreen:callStateListener]   - Participant: userId=${p.userId}, name=${p.name}');
        }

        if (mounted) {
          setState(() {
            _callState = state;
          });
        }

        // Auto-dismiss screen when call ends
        if (state.status is CallStatusDisconnected) {
          debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] Call status is DISCONNECTED, dismissing screen in 2s');
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] Popping video chat screen');
              context.pop();
            }
          });
        }

        // Monitor participant count for 1-on-1 calls
        // Track if we've ever had multiple participants
        if (state.callParticipants.length >= 2) {
          if (!_hadMultipleParticipants) {
            _hadMultipleParticipants = true;
            debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] Multiple participants (2+) detected for first time, will monitor for disconnects');
          }
        }

        // Only end the call if we previously had 2+ participants and now we're alone
        // This prevents ending the call when the caller is waiting for the other person to join
        if (!_isEnding && _hasAcceptedCall && _hadMultipleParticipants) {
          debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] Checking for disconnect (isEnding=$_isEnding, hasAccepted=$_hasAcceptedCall, hadMultiple=$_hadMultipleParticipants)');

          // Simple check: if total participants is 1 or less, the other person left
          if (state.callParticipants.length <= 1) {
            debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] Participant count <= 1 (was 2+), other person left, ending call');
            _endCall();
            return;
          }

          // Additional check: filter by user ID to be sure
          final myUserId = _authService.userInfo?.id.toString();
          final otherParticipants = state.callParticipants.where(
            (p) => p.userId != myUserId
          ).toList();

          debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] Other participants (excluding me): ${otherParticipants.length}');

          // If no other participants remain, end the call
          if (otherParticipants.isEmpty) {
            debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] No other participants found, ending call');
            _endCall();
          }
        } else {
          if (_isEnding) {
            debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] Already ending call, skipping disconnect check');
          } else if (!_hasAcceptedCall) {
            debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] Call not yet accepted, skipping disconnect check');
          } else if (!_hadMultipleParticipants) {
            debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] Never had 2+ participants, skipping disconnect check');
          }
        }
        debugPrint('[VC] 📞 [VideoChatScreen:callStateListener] ========== CALL STATE PROCESSING COMPLETE ==========');
      });

      debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] Call state listener configured');
      debugPrint('[VC] 📞 [VideoChatScreen:_initializeCall] << EXIT: Initialization complete');
    } catch (e) {
      debugPrint('[VC] ❌ [VideoChatScreen:_initializeCall] << EXIT: Error during initialization: $e');
      debugPrint('[VC] ❌ [VideoChatScreen:_initializeCall] Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _error = 'Failed to connect to call: $e';
          _isLoading = false;
        });
      }
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

  Future<void> _acceptCall() async {
    debugPrint('[VC] 📞 [VideoChatScreen:_acceptCall] >> ENTRY: Student accepting call');
    debugPrint('[VC] 📞 [VideoChatScreen:_acceptCall] Call ID: ${widget.callId}');
    debugPrint('[VC] 📞 [VideoChatScreen:_acceptCall] Call exists: ${_call != null}');

    setState(() {
      _isAccepting = true;
    });
    debugPrint('[VC] 📞 [VideoChatScreen:_acceptCall] State updated: isAccepting=true');

    try {
      // Request permissions
      debugPrint('[VC] 📞 [VideoChatScreen:_acceptCall] Requesting camera and microphone permissions...');
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      debugPrint('[VC] 📞 [VideoChatScreen:_acceptCall] Permission results:');
      debugPrint('[VC] 📞 [VideoChatScreen:_acceptCall]   - Camera: ${statuses[Permission.camera]}');
      debugPrint('[VC] 📞 [VideoChatScreen:_acceptCall]   - Microphone: ${statuses[Permission.microphone]}');

      final allGranted = statuses.values.every((status) => status.isGranted);

      if (!allGranted) {
        debugPrint('[VC] ❌ [VideoChatScreen:_acceptCall] << EXIT: Permissions NOT granted');
        if (mounted) {
          _showPermissionSettingsDialog();
        }
        setState(() {
          _isAccepting = false;
        });
        return;
      }

      debugPrint('[VC] 📞 [VideoChatScreen:_acceptCall] Permissions granted, proceeding to accept call');

      // Accept the ringing call (not join - accept is for ringing calls)
      if (_call != null) {
        debugPrint('[VC] 📞 [VideoChatScreen:_acceptCall] Calling accept() on ringing call: ${_call!.id}');
        await _call!.accept();
        debugPrint('[VC] 📞 [VideoChatScreen:_acceptCall] Successfully accepted call');

        // Update service state
        _videoService.setActiveCall(_call!);

        // The StreamCallContainer will now handle the active call UI
        if (mounted) {
          setState(() {
            _isAccepting = false;
            _hasAcceptedCall = true;  // Mark call as accepted to transition UI
          });
        }
      }
    } catch (e) {
      debugPrint('[VIDEO_CALL] Error accepting call: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to accept call: $e';
          _isAccepting = false;
        });
      }
    }
  }

  Future<void> _declineCall() async {
    debugPrint('[VIDEO_CALL] Student declining call');
    debugPrint('[VIDEO_CALL] Call ID: ${widget.callId}');

    try {
      if (_call != null) {
        await _call!.reject();
        debugPrint('[VIDEO_CALL] Call rejected successfully');
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      debugPrint('[VIDEO_CALL] Error declining call: $e');
      if (mounted) {
        context.pop();
      }
    }
  }

  void _endCall() async {
    // Prevent recursive calls
    if (_isEnding) {
      debugPrint('[VIDEO_CALL] Already ending call, skipping');
      return;
    }

    debugPrint('[VIDEO_CALL] Ending call');
    debugPrint('[VIDEO_CALL] Call ID: ${widget.callId}');

    setState(() {
      _isEnding = true;
    });

    try {
      if (_call != null) {
        await _call!.leave();
        debugPrint('[VIDEO_CALL] Left call successfully');
      }
      _videoService.clearActiveCall();
    } catch (e) {
      debugPrint('[VIDEO_CALL] Error leaving call: $e');
    }

    if (mounted) {
      context.pop();
    }
  }

  @override
  void dispose() {
    debugPrint('[VIDEO_CALL] VideoChatScreen.dispose()');
    _callStateSubscription?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
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
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Error state
    if (_error != null || _call == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF020817),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error ?? 'Failed to connect',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Incoming call state (student, not yet accepted)
    if (widget.isIncoming && !_hasAcceptedCall) {
      return _buildIncomingCallUI();
    }

    // Active call state - Use StreamCallContainer
    // This handles both outgoing (mentor) and active (student after accept) calls
    debugPrint('[VIDEO_CALL] Building StreamCallContainer for call ${_call!.id}');

    return StreamCallContainer(
      call: _call!,
      onBackPressed: () {
        debugPrint('[VIDEO_CALL] Back pressed in StreamCallContainer');
        _endCall();
      },
      onLeaveCallTap: () {
        debugPrint('[VIDEO_CALL] Leave call tapped in StreamCallContainer');
        _endCall();
      },
    );
  }

  Widget _buildIncomingCallUI() {
    final displayName = widget.callerName ?? 'Mentor';

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
                    color: Colors.white.withOpacity(0.2),
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
