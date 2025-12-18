import 'package:flutter/material.dart';
import 'base_video_chat_screen.dart';

/// Video chat screen for MENTORS (outgoing calls)
/// Mentor creates the call, joins immediately, and waits for student to connect
class MentorVideoChatScreen extends BaseVideoChatScreen {
  final String? recipientName;

  const MentorVideoChatScreen({
    super.key,
    required super.callId,
    this.recipientName,
  });

  @override
  State<MentorVideoChatScreen> createState() => _MentorVideoChatScreenState();
}

class _MentorVideoChatScreenState extends BaseVideoChatScreenState<MentorVideoChatScreen> {

  @override
  String get displayName => widget.recipientName ?? 'Student';

  @override
  void initState() {
    super.initState();
    debugPrint('[VC] 📞 [MentorVideoChatScreen] recipientName: ${widget.recipientName}');
    // Mentor always starts in "accepted" state - they initiated the call
    hasAcceptedCall = true;
  }

  @override
  Future<void> initializeCall() async {
    debugPrint('[VC] 📞 [MentorVideoChatScreen:initializeCall] >> ENTRY');

    try {
      // Setup the call
      final newCall = await setupCall();

      // Mentor joins immediately
      debugPrint('[VC] 📞 [MentorVideoChatScreen:initializeCall] Joining call as mentor...');
      await newCall.join();
      videoService.setActiveCall(newCall);
      debugPrint('[VC] 📞 [MentorVideoChatScreen:initializeCall] Joined call successfully');

      if (mounted) {
        setState(() {
          call = newCall;
          isLoading = false;
        });
      }

      // Setup state listener
      setupCallStateListener();

      debugPrint('[VC] 📞 [MentorVideoChatScreen:initializeCall] << EXIT: Initialization complete');
    } catch (e) {
      debugPrint('[VC] ❌ [MentorVideoChatScreen:initializeCall] << EXIT: Error: $e');
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
    // Mentor always shows active call UI (StreamCallContainer)
    return buildActiveCallUI();
  }
}
