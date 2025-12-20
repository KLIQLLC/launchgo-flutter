import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/auth_service.dart';
import '../../services/video_call/stream_video_service.dart';
import '../../widgets/chat/custom_attachment_handler.dart';
import 'dart:async';

class CustomChatWidget extends StatefulWidget {
  final StreamChatClient client;
  final Channel channel;

  const CustomChatWidget({
    Key? key,
    required this.client,
    required this.channel,
  }) : super(key: key);
  
  @override
  State<CustomChatWidget> createState() {
    return _CustomChatWidgetState();
  }
}

class _CustomChatWidgetState extends State<CustomChatWidget> {
  late StreamMessageInputController _messageInputController;
  
  @override
  void initState() {
    super.initState();
    _messageInputController = StreamMessageInputController();
    
    // Mark messages as read when user opens the chat UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.channel.markRead();
    });
  }
  
  @override
  void dispose() {
    _messageInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the current theme
    final streamTheme = StreamChatTheme.of(context);
    
    // Create custom theme with message colors
    final customTheme = streamTheme.copyWith(
      // Set the main chat background color
      colorTheme: streamTheme.colorTheme.copyWith(
        appBg: const Color(0xFF020817), // Main chat background
        barsBg: const Color(0xFF0F1828), // App bar background
        inputBg: const Color(0xFF1A2332), // Input background
      ),
      ownMessageTheme: streamTheme.ownMessageTheme.copyWith(
        messageBackgroundColor: const Color(0xFFF8FAFC), // Light background for own messages
        messageTextStyle: const TextStyle(
          color: Color(0xFF0E172A), // Dark blue text for own messages
          fontSize: 15,
        ),
        repliesStyle: const TextStyle(
          color: Color(0xFF64748B), // Muted dark text for replies
        ),
      ),
      otherMessageTheme: streamTheme.otherMessageTheme.copyWith(
        messageBackgroundColor: const Color(0xFF1A2332), // Dark card background
        messageTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 15,
        ),
        repliesStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
      messageInputTheme: streamTheme.messageInputTheme.copyWith(
        inputBackgroundColor: const Color(0xFF1A2332),
        inputTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 15,
        ),
        sendButtonColor: const Color(0xFF7B8CDE),
        actionButtonColor: const Color(0xFF7B8CDE),
        actionButtonIdleColor: const Color(0xFF64748B),
        idleBorderGradient: const LinearGradient(
          colors: [Color(0xFF2A3441), Color(0xFF2A3441)],
        ),
      ),
      messageListViewTheme: streamTheme.messageListViewTheme.copyWith(
        backgroundColor: const Color(0xFF020817), // Message list background
      ),
    );
    
    return StreamChatTheme(
      data: customTheme,
      child: StreamChannel(
        channel: widget.channel,
        child: Scaffold(
          backgroundColor: const Color(0xFF020817), // Dark blue-black background
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: _CustomChatAppBar(channel: widget.channel),
          ),
          body: Column(
            children: <Widget>[
              Expanded(
                child: StreamMessageListView(
                  messageBuilder: (context, details, messages, defaultWidget) {
                    // You can return custom message widget here if needed
                    return defaultWidget.copyWith(
                      showUsername: true,
                      showTimestamp: true,
                      showSendingIndicator: true,
                    );
                  },
                ),
              ),
              StreamMessageInput(
                messageInputController: _messageInputController,
                disableAttachments: false,
                showCommandsButton: false,
                attachmentButtonBuilder: (context, defaultButton) {
                  return IconButton(
                    onPressed: () async {
                      await CustomAttachmentHandler.showAttachmentOptions(
                        context: context,
                        messageInputController: _messageInputController,
                      );
                    },
                    icon: SvgPicture.asset(
                      'assets/icons/ic_attachment.svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF64748B), // Muted icon color
                        BlendMode.srcIn,
                      ),
                    ),
                  );
                },
                sendButtonBuilder: (context, messageController) {
                  return AnimatedBuilder(
                    animation: messageController,
                    builder: (context, child) {
                      final hasText = messageController.text.trim().isNotEmpty;
                      final hasAttachments = messageController.attachments.isNotEmpty;
                      final canSend = hasText || hasAttachments;
                      
                      return IconButton(
                        onPressed: canSend
                            ? () {
                                // Send message using the controller
                                final channel = StreamChannel.of(context).channel;
                                final message = Message(
                                  text: messageController.text.trim(),
                                  attachments: messageController.attachments,
                                );
                                
                                channel.sendMessage(message);
                                messageController.clear();
                              }
                            : null,
                        icon: SvgPicture.asset(
                          'assets/icons/ic_send.svg',
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            canSend
                              ? const Color(0xFF7B8CDE)  // Active send button color
                              : const Color(0xFF64748B), // Disabled send button color
                            BlendMode.srcIn,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomChatAppBar extends StatefulWidget {
  final Channel channel;
  const _CustomChatAppBar({required this.channel});

  @override
  State<_CustomChatAppBar> createState() => _CustomChatAppBarState();
}

class _CustomChatAppBarState extends State<_CustomChatAppBar> {
  StreamSubscription? _channelSubscription;
  Timer? _statusRefreshTimer;
  bool isOnline = false;

  String displayName = '';
  String displayAvatar = '';
  String? otherUserId;

  @override
  void initState() {
    super.initState();
    _initUserData();
    _subscribeToChannelEvents();
    _updateOnlineStatus();
    
    // Set up periodic refresh for status (every 5 seconds)
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateOnlineStatus();
    });
  }

  void _initUserData() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.userInfo;
    if (user == null) {
      displayName = 'Unknown';
    } else if (user.isStudent) {
      // if student
      displayName = user.mentorName ?? 'Mentor';
      displayAvatar = user.mentorAvatar ?? '';
      otherUserId = user.mentorId;
    } else if (user.isMentor) {
      // if mentor
      final selectedStudent = authService.getSelectedStudent();
      displayName = selectedStudent?.name ?? 'Client';
      displayAvatar = selectedStudent?.avatarUrl ?? '';
      otherUserId = selectedStudent?.id;
    }
  }

  void _subscribeToChannelEvents() {
    _channelSubscription = widget.channel.on().listen((event) {
      // Listen for various presence and user events
      if (event.type == 'user.presence.changed' ||
          event.type == 'user.watching.start' ||
          event.type == 'user.watching.stop' ||
          event.type == 'user.updated' ||
          event.type == 'member.updated' ||
          event.type == 'health.check') {
        _updateOnlineStatus();
      }
    });
    
    // Also listen to channel state changes
    widget.channel.state?.membersStream.listen((_) {
      _updateOnlineStatus();
    });
  }

  void _updateOnlineStatus() {
    if (!mounted) return;
    
    final members = widget.channel.state?.members ?? [];
    
    final otherMember = members.firstWhere(
      (m) => m.userId == otherUserId,
      orElse: () => members.isNotEmpty ? members.first : Member(userId: '', user: null),
    );
    
    final newOnlineStatus = otherMember.user?.online ?? false;
    if (newOnlineStatus != isOnline) {
      setState(() {
        isOnline = newOnlineStatus;
      });
    }
  }

  @override
  void dispose() {
    _channelSubscription?.cancel();
    _statusRefreshTimer?.cancel();
    super.dispose();
  }

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

  Future<void> _initiateVideoCall(BuildContext context, AuthService authService) async {
    debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] >> ENTRY: Mentor initiating video call');

    // Request permissions immediately
    debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Requesting camera and microphone permissions');
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Permission results - Camera: ${statuses[Permission.camera]}, Microphone: ${statuses[Permission.microphone]}');

    final allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      debugPrint('[VC] ⚠️ [CustomChatWidget:_initiateVideoCall] Permissions not granted, showing settings dialog');
      if (context.mounted) {
        _showPermissionSettingsDialog(context);
      }
      return;
    }

    debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Permissions granted');

    final selectedStudent = authService.getSelectedStudent();
    if (selectedStudent == null) {
      debugPrint('[VC] ⚠️ [CustomChatWidget:_initiateVideoCall] No student selected');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No student selected'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Selected student: ${selectedStudent.name} (${selectedStudent.id})');

    if (!context.mounted) return;
    final videoService = context.read<StreamVideoService>();

    // Ensure video service is initialized
    if (videoService.client == null) {
      debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Video service not initialized, initializing now');
      final userInfo = authService.userInfo;
      if (userInfo != null && userInfo.callGetStreamToken != null) {
        await videoService.initialize(userInfo);
        debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Video service initialized');
      } else {
        debugPrint('[VC] ❌ [CustomChatWidget:_initiateVideoCall] Cannot initialize video service - no token');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video service initialization failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (!context.mounted) return;

    // Generate unique call ID with timestamp
    final uniqueCallId = '${selectedStudent.id}_${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Creating call with ID: $uniqueCallId');

    try {
      // Create call using the official pattern with ringing: true
      final client = videoService.client!;
      final call = client.makeCall(
        callType: StreamCallType.defaultType(),
        id: uniqueCallId,
      );

      debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Calling getOrCreate with ringing: true');
      final result = await call.getOrCreate(
        memberIds: [selectedStudent.id],
        ringing: true,  // Triggers push notification to student
      );

      result.fold(
        success: (success) {
          debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Call created successfully');
          debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Navigating to mentor-video-chat screen');

          if (context.mounted) {
            context.pushNamed(
              'mentor-video-chat',
              pathParameters: {'callId': uniqueCallId},
              queryParameters: {
                'recipientName': selectedStudent.name,
              },
            );
          }
        },
        failure: (failure) {
          debugPrint('[VC] ❌ [CustomChatWidget:_initiateVideoCall] Failed to create call: ${failure.error.message}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to create call: ${failure.error.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('[VC] ❌ [CustomChatWidget:_initiateVideoCall] Error creating call: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: const Color(0xFF0F1828), // Slightly lighter than background for app bar
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: displayAvatar.isNotEmpty ? NetworkImage(displayAvatar) : null,
              backgroundColor: Colors.grey[800],
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: isOnline ? Colors.green : Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Video call button (mentor only)
            Consumer<AuthService>(
              builder: (context, authService, _) {
                final isMentor = authService.userInfo?.isMentor ?? false;
                if (!isMentor) return const SizedBox.shrink();

                return IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.white),
                  onPressed: () => _initiateVideoCall(context, authService),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                // Try to pop first, if not possible, navigate to schedule
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  // If no navigation stack (opened via push notification), go to schedule
                  context.go('/schedule');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
