import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:launchgo/utils/call_debug_logger.dart';
import 'package:provider/provider.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:go_router/go_router.dart';
import '../../services/video_call/stream_video_service.dart';
import '../../services/auth_service.dart';

/// Base class for video chat screens
/// Contains common functionality shared between Mentor and Student screens
abstract class BaseVideoChatScreen extends StatefulWidget {
  final String callId;

  const BaseVideoChatScreen({
    super.key,
    required this.callId,
  });
}

/// Base state class with common video call functionality
abstract class BaseVideoChatScreenState<T extends BaseVideoChatScreen> extends State<T> {
  late final StreamVideoService videoService;
  late final AuthService authService;

  Call? call;
  StreamSubscription<CallState>? callStateSubscription;
  bool isLoading = true;
  bool isEnding = false;
  bool hadMultipleParticipants = false;
  bool hasAcceptedCall = false;
  String? error;
  CallState? callState;

  /// Name to display in UI (implemented by subclasses)
  String get displayName;

  @override
  void initState() {
    super.initState();
    debugPrint('[VC] 📞 [$runtimeType] initState()');
    debugPrint('[VC] 📞 [$runtimeType]   callId: ${widget.callId}');

    videoService = context.read<StreamVideoService>();
    authService = context.read<AuthService>();
    WakelockPlus.enable();

    initializeCall();
  }

  /// Initialize the call - implemented by subclasses
  Future<void> initializeCall();

  /// Common call setup logic
  Future<Call> setupCall() async {
    debugPrint('[VC] 📞 [$runtimeType:setupCall] >> ENTRY');

    final client = videoService.client;
    debugPrint('[VC] 📞 [$runtimeType:setupCall] Video client exists: ${client != null}');

    if (client == null) {
      throw Exception('Video client not initialized');
    }

    debugPrint('[VC] 📞 [$runtimeType:setupCall] Creating call reference for callId: ${widget.callId}');
    final newCall = client.makeCall(
      callType: StreamCallType.defaultType(),
      id: widget.callId,
    );
    debugPrint('[VC] 📞 [$runtimeType:setupCall] Call reference created');

    debugPrint('[VC] 📞 [$runtimeType:setupCall] Fetching call with getOrCreate()...');
    await newCall.getOrCreate();
    debugPrint('[VC] 📞 [$runtimeType:setupCall] Call fetched successfully: ${newCall.id}');

    return newCall;
  }

  /// Setup call state listener - common for all screens
  void setupCallStateListener() {
    debugPrint('[VC] 📞 [$runtimeType:setupCallStateListener] Setting up call state listener...');

    callStateSubscription = call!.state.listen((state) async {
      await CallDebugLogger.log('[$runtimeType] callState=${state.status} participants=${state.callParticipants.length} callId=${widget.callId}');
      debugPrint('[VC] 📞 [$runtimeType:callStateListener] ========== CALL STATE CHANGED ==========');
      debugPrint('[VC] 📞 [$runtimeType:callStateListener] Status: ${state.status}');
      debugPrint('[VC] 📞 [$runtimeType:callStateListener] Total participants: ${state.callParticipants.length}');

      for (var p in state.callParticipants) {
        debugPrint('[VC] 📞 [$runtimeType:callStateListener]   - Participant: userId=${p.userId}, name=${p.name}');
      }

      if (mounted) {
        setState(() {
          callState = state;
        });
      }

      // Auto-dismiss screen when call ends
      if (state.status is CallStatusDisconnected) {
        await CallDebugLogger.log('[$runtimeType] CallStatusDisconnected detected, dismissing in 2s');
        debugPrint('[VC] 📞 [$runtimeType:callStateListener] Call status is DISCONNECTED, dismissing screen in 2s');
        Future.delayed(const Duration(seconds: 2), () async {
          if (mounted && !isEnding) {
            await CallDebugLogger.log('[$runtimeType] Navigating back after disconnect, clearing active call');
            debugPrint('[VC] 📞 [$runtimeType:callStateListener] Navigating back after disconnect');
            isEnding = true; // Prevent multiple navigation attempts
            videoService.clearActiveCall();
            navigateBack();
          }
        });
      }

      // Monitor participant count for 1-on-1 calls
      if (state.callParticipants.length >= 2) {
        if (!hadMultipleParticipants) {
          hadMultipleParticipants = true;
          debugPrint('[VC] 📞 [$runtimeType:callStateListener] Multiple participants (2+) detected for first time');
        }
      }

      // End call if other person left
      if (!isEnding && hasAcceptedCall && hadMultipleParticipants) {
        if (state.callParticipants.length <= 1) {
          debugPrint('[VC] 📞 [$runtimeType:callStateListener] Participant count <= 1 (was 2+), other person left, ending call');
          endCall();
          return;
        }

        final myUserId = authService.userInfo?.id.toString();
        final otherParticipants = state.callParticipants.where(
          (p) => p.userId != myUserId
        ).toList();

        if (otherParticipants.isEmpty) {
          debugPrint('[VC] 📞 [$runtimeType:callStateListener] No other participants found, ending call');
          endCall();
        }
      }
      debugPrint('[VC] 📞 [$runtimeType:callStateListener] ========== CALL STATE PROCESSING COMPLETE ==========');
    });

    debugPrint('[VC] 📞 [$runtimeType:setupCallStateListener] Call state listener configured');
  }

  /// End the call - common for all screens
  Future<void> endCall() async {
    if (isEnding) {
      debugPrint('[VC] 📞 [$runtimeType:endCall] Already ending call, skipping');
      return;
    }

    await CallDebugLogger.log('[$runtimeType] endCall START callId=${widget.callId}');
    debugPrint('[VC] 📞 [$runtimeType:endCall] Ending call ${widget.callId}');

    setState(() {
      isEnding = true;
    });

    try {
      if (call != null) {
        await call!.leave();
        await CallDebugLogger.log('[$runtimeType] call.leave() OK');
        debugPrint('[VC] 📞 [$runtimeType:endCall] Left call successfully');
      }
      await CallDebugLogger.log('[$runtimeType] calling clearActiveCall()');
      videoService.clearActiveCall();
    } catch (e) {
      await CallDebugLogger.log('[$runtimeType] endCall ERROR: $e');
      debugPrint('[VC] ❌ [$runtimeType:endCall] Error leaving call: $e');
    }

    // End CallKit notification (Android only) to clean up properly
    // This prevents stale CallKit state from blocking future notifications
    if (Platform.isAndroid) {
      try {
        debugPrint('[VC] 📞 [$runtimeType:endCall] Ending CallKit notification');
        await FlutterCallkitIncoming.endAllCalls();
        debugPrint('[VC] 📞 [$runtimeType:endCall] CallKit notification ended');
      } catch (e) {
        debugPrint('[VC] ⚠️ [$runtimeType:endCall] Error ending CallKit: $e');
      }
    }

    await CallDebugLogger.log('[$runtimeType] endCall COMPLETE, navigating back');
    navigateBack();
  }

  /// Safely navigate back - handles both normal and terminated-state launches
  /// Protected so subclasses can use it
  @protected
  void navigateBack() {
    if (!mounted) return;

    debugPrint('[VC] 📞 [$runtimeType:navigateBack] Attempting to navigate back');

    // Check if we can pop (have navigation history)
    if (Navigator.of(context).canPop()) {
      debugPrint('[VC] 📞 [$runtimeType:navigateBack] Can pop - using context.pop()');
      context.pop();
    } else {
      // App was launched from terminated state - no history to pop to
      // Navigate to schedule as the home screen
      debugPrint('[VC] 📞 [$runtimeType:navigateBack] Cannot pop - navigating to /schedule');
      context.go('/schedule');
    }
  }

  @override
  void dispose() {
    debugPrint('[VC] 📞 [$runtimeType] dispose()');
    callStateSubscription?.cancel();
    WakelockPlus.disable();

    // Clean up CallKit notification as a safety net (Android only)
    if (Platform.isAndroid) {
      FlutterCallkitIncoming.endAllCalls().catchError((e) {
        debugPrint('[VC] ⚠️ [$runtimeType:dispose] Error ending CallKit: $e');
      });
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (isLoading) {
      return buildLoadingUI();
    }

    // Error state
    if (error != null || call == null) {
      return buildErrorUI();
    }

    // Call-specific UI (implemented by subclasses)
    return buildCallUI();
  }

  /// Build UI for call state - implemented by subclasses
  Widget buildCallUI();

  /// Build loading UI - common
  Widget buildLoadingUI() {
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
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build error UI - common
  Widget buildErrorUI() {
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
                error ?? 'Failed to connect',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: navigateBack,
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build active call UI with StreamCallContainer - common
  Widget buildActiveCallUI() {
    debugPrint('[VC] 📞 [$runtimeType:buildActiveCallUI] Building StreamCallContainer for call ${call!.id}');

    return StreamCallContainer(
      call: call!,
      onBackPressed: () {
        debugPrint('[VC] 📞 [$runtimeType:buildActiveCallUI] Back pressed');
        endCall();
      },
      onLeaveCallTap: () {
        debugPrint('[VC] 📞 [$runtimeType:buildActiveCallUI] Leave call tapped');
        endCall();
      },
    );
  }
}
