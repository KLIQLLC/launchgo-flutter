// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:stream_video_flutter/stream_video_flutter.dart';
// import 'package:wakelock_plus/wakelock_plus.dart';
// import 'package:go_router/go_router.dart';
// import '../../services/video_call/stream_video_service.dart';
//
// /// Video call screen showing active call with controls
// /// Used by both mentors and students during an active call
// class VideoCallScreen extends StatefulWidget {
//   final String callId;
//   final String recipientName;
//   final bool callAlreadyJoined; // True if call was joined via CallKit/ringing events
//
//   const VideoCallScreen({
//     super.key,
//     required this.callId,
//     required this.recipientName,
//     this.callAlreadyJoined = false,
//   });
//
//   @override
//   State<VideoCallScreen> createState() => _VideoCallScreenState();
// }
//
// class _VideoCallScreenState extends State<VideoCallScreen> {
//   late final StreamVideoService _videoService;
//   Call? _call;
//   bool _isLoading = true;
//   String? _error;
//
//   @override
//   void initState() {
//     super.initState();
//     debugPrint('🎥 [VideoCallScreen] initState called - callId: ${widget.callId}, recipientName: ${widget.recipientName}, callAlreadyJoined: ${widget.callAlreadyJoined}');
//     _videoService = context.read<StreamVideoService>();
//     WakelockPlus.enable(); // Keep screen on during call
//     _initializeCall();
//   }
//
//   Future<void> _initializeCall() async {
//     debugPrint('🎥 [VideoCallScreen] _initializeCall starting for callId: ${widget.callId}');
//
//     // First check if we have an activeCall from the service (set during createCall or acceptIncomingCall)
//     final existingCall = _videoService.activeCall;
//     debugPrint('🎥 [VideoCallScreen] Existing activeCall from service: $existingCall');
//
//     if (existingCall != null && existingCall.id == widget.callId) {
//       debugPrint('🎥 [VideoCallScreen] Using existing activeCall: ${existingCall.id}');
//       if (mounted) {
//         setState(() {
//           _call = existingCall;
//           _isLoading = false;
//         });
//       }
//       return;
//     }
//
//     // If no activeCall, try to get the call from the client using the callId
//     debugPrint('🎥 [VideoCallScreen] No matching activeCall, fetching call by ID: ${widget.callId}');
//     final client = _videoService.client;
//
//     if (client == null) {
//       debugPrint('❌ [VideoCallScreen] Client is null - cannot fetch call');
//       if (mounted) {
//         setState(() {
//           _error = 'Video client not initialized';
//           _isLoading = false;
//         });
//       }
//       return;
//     }
//
//     try {
//       final call = client.makeCall(
//         callType: StreamCallType.defaultType(),
//         id: widget.callId,
//       );
//
//       // Get or create ensures we have the call state
//       await call.getOrCreate();
//       debugPrint('🎥 [VideoCallScreen] Call fetched successfully: ${call.id}');
//
//       if (mounted) {
//         setState(() {
//           _call = call;
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       debugPrint('❌ [VideoCallScreen] Error fetching call: $e');
//       if (mounted) {
//         setState(() {
//           _error = 'Failed to connect to call';
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//   @override
//   void dispose() {
//     WakelockPlus.disable();
//     // End call when screen is disposed (user backs out or screen is closed)
//     _videoService.endCall(); // Don't await in dispose
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     debugPrint('🎥 [VideoCallScreen] build() called - _call: $_call, _isLoading: $_isLoading, _error: $_error');
//
//     if (_isLoading) {
//       return Scaffold(
//         backgroundColor: const Color(0xFF020817),
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const CircularProgressIndicator(color: Colors.white),
//               const SizedBox(height: 16),
//               Text(
//                 'Connecting...',
//                 style: TextStyle(
//                   color: Colors.white.withAlpha(179), // ~0.7 opacity
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     if (_error != null || _call == null) {
//       return Scaffold(
//         backgroundColor: const Color(0xFF020817),
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.error_outline, color: Colors.red, size: 48),
//               const SizedBox(height: 16),
//               Text(
//                 _error ?? 'Failed to connect',
//                 style: const TextStyle(color: Colors.white),
//               ),
//               const SizedBox(height: 24),
//               ElevatedButton(
//                 onPressed: () => context.pop(),
//                 child: const Text('Go Back'),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     debugPrint('🎥 [VideoCallScreen] Call ready - callAlreadyJoined: ${widget.callAlreadyJoined}');
//
//     // If call was already joined (via CallKit/ringing events), use StreamCallContent directly
//     // to avoid StreamCallContainer calling join() again
//     if (widget.callAlreadyJoined) {
//       debugPrint('🎥 [VideoCallScreen] Using StreamCallContent (call already joined)');
//       // Use StreamBuilder to listen to call state changes and rebuild UI accordingly
//       // This ensures the video streams update when participants join/leave
//       return StreamBuilder<CallState>(
//         stream: _call!.state.asStream(),
//         initialData: _call!.state.value,
//         builder: (context, snapshot) {
//           final callState = snapshot.data ?? _call!.state.value;
//           debugPrint('🎥 [VideoCallScreen] StreamBuilder rebuild - status: ${callState.status}');
//
//           return StreamCallContent(
//             call: _call!,
//             callState: callState,
//             onBackPressed: () {
//               _videoService.endCall();
//               if (mounted) {
//                 context.pop();
//               }
//             },
//             onLeaveCallTap: () {
//               _videoService.endCall();
//               if (mounted) {
//                 context.pop();
//               }
//             },
//           );
//         },
//       );
//     }
//
//     debugPrint('🎥 [VideoCallScreen] Using StreamCallContainer for call ${_call!.id}');
//
//     // Use StreamCallContainer with default UI (following Stream's official sample pattern)
//     // This handles call join, participant management, UI controls automatically
//     return StreamCallContainer(
//       call: _call!,
//       onBackPressed: () {
//         _videoService.endCall();
//         if (mounted) {
//           context.pop();
//         }
//       },
//     );
//   }
// }
