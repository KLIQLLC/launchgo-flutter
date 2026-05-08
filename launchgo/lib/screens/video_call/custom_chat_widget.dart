// screens/video_call/custom_chat_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video/src/utils/result.dart' as sv_result;
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/auth_service.dart';
import '../../services/video_call/stream_video_service.dart';
import '../../widgets/chat/custom_attachment_handler.dart';
import 'dart:async';
import '../../utils/call_debug_logger.dart';

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
                  systemMessageBuilder: (context, message) {
                    final rawText = message.text ?? '';
                    if (rawText.isEmpty) {
                      // Fallback to Stream's default renderer for empty system messages
                      return StreamSystemMessage(message: message);
                    }

                    // Only customize the "call" system messages (keep other system messages default).
                    final lower = rawText.toLowerCase();
                    final isCallSystemMessage = lower.contains('call started') ||
                        lower.contains('call ended') ||
                        lower.contains('call declined') ||
                        lower.contains('call missed');

                    if (!isCallSystemMessage) {
                      return StreamSystemMessage(message: message);
                    }

                    // Extract call event type from text
                    String event = 'call';
                    if (lower.contains('started')) event = 'started';
                    else if (lower.contains('ended')) event = 'ended';
                    else if (lower.contains('declined')) event = 'declined';
                    else if (lower.contains('missed')) event = 'missed';

                    // Format time from message.createdAt (convert UTC to local time)
                    final localTime = message.createdAt.toLocal();
                    final time = TimeOfDay.fromDateTime(localTime);
                    final timeStr = MaterialLocalizations.of(context).formatTimeOfDay(
                      time,
                      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
                    );

                    final displayText = 'Call $event ($timeStr)';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.call,
                                size: 14,
                                color: Color(0xFFCBD5E1),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                displayText,
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  messageBuilder: (context, details, messages, defaultWidget) {
                    // Keep Stream defaults (username only on first message in a streak for others).
                    return defaultWidget;
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
  /// Prevents duplicate calls when mentor taps call button multiple times
  bool _startingVideoCall = false;

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
    // Prevent duplicate calls if mentor taps rapidly
    if (_startingVideoCall) {
      debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Already starting call, ignoring');
      return;
    }
    _startingVideoCall = true;
    
    try {
      debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] >> ENTRY: Mentor initiating video call');

      // First, ensure video service is initialized BEFORE requesting permissions
      // This ensures the service is ready even if permissions are denied
      if (!context.mounted) return;
      final videoService = context.read<StreamVideoService>();

      // We don't proactively refresh based on token expiry (video token is long-lived).
      // Only refresh user info if the token is missing.
      var userInfo = authService.userInfo;
      if (userInfo == null || userInfo.callGetStreamToken == null || userInfo.callGetStreamToken!.isEmpty) {
        debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Video token missing, refreshing user info...');
        try {
          await authService.refreshUserInfo();
          userInfo = authService.userInfo;
          debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] User info refreshed, token available: ${userInfo?.callGetStreamToken != null && userInfo!.callGetStreamToken!.isNotEmpty}');
        } catch (e) {
          debugPrint('[VC] ❌ [CustomChatWidget:_initiateVideoCall] Failed to refresh user info: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to refresh session: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (!context.mounted) return;

      if (videoService.client == null) {
        debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Video service not initialized, initializing now (before permissions)');
        if (userInfo != null && userInfo.callGetStreamToken != null) {
          try {
            await videoService.initialize(userInfo);
            debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Video service initialized successfully');
          } catch (e) {
            debugPrint('[VC] ❌ [CustomChatWidget:_initiateVideoCall] Failed to initialize video service: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to initialize video service: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        } else {
          debugPrint('[VC] ❌ [CustomChatWidget:_initiateVideoCall] Cannot initialize: userInfo or token is null');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video service not available. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Verify client is available after initialization
      if (videoService.client == null) {
        debugPrint('[VC] ❌ [CustomChatWidget:_initiateVideoCall] Video client is still null after initialization');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video service not ready. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Now request permissions (after service is initialized)
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

      // Generate unique call ID with timestamp
      final uniqueCallId = '${selectedStudent.id}_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Creating call with ID: $uniqueCallId');

      // Create call using the official pattern with ringing: true
      final client = videoService.client;
      if (client == null) {
        debugPrint('[VC] ❌ [CustomChatWidget:_initiateVideoCall] Video client is null');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video service not ready. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final call = client.makeCall(
        callType: StreamCallType.defaultType(),
        id: uniqueCallId,
      );

      debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Calling getOrCreate with ringing: true');
      await CallDebugLogger.log(
        '[CALL_CREATE] getOrCreate: callId=$uniqueCallId memberId=${selectedStudent.id} ringing=true notify=false',
      );

      late final dynamic result;
      try {
        result = await call.getOrCreate(
          memberIds: [selectedStudent.id],
          ringing: true, // Triggers VoIP push (CallKit)
          notify: false, // Do NOT send regular "calling you" push during ringing
          // Keep missed-call push, but make it match our CallKit ring duration (60s)
          // so "missed" doesn't fire early.
          ring: const StreamRingSettings(
            autoCancelTimeout: Duration(seconds: 60),
            autoRejectTimeout: Duration(seconds: 60),
            missedCallTimeout: Duration(seconds: 60),
          ),
        );
      } catch (e, st) {
        debugPrint('[VC] ❌ [CustomChatWidget:_initiateVideoCall] getOrCreate threw: $e\n$st');
        await CallDebugLogger.log(
          '[CALL_CREATE][ERROR] getOrCreate threw: $e\n$st',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start call. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (result is sv_result.Success) {
          debugPrint('[VC] 📞 [CustomChatWidget:_initiateVideoCall] Call created successfully');

          // Send call started message (system message, time added on render from createdAt)
          try {
            unawaited(
              widget.channel.sendMessage(
                Message(
                  type: 'system',
                  text: '📞 Call started',
                  silent: true, // does not increase unread count, does not mark channel as unread
                  extraData: const {
                    'event_type': 'call',
                    'call_event': 'started',
                  },
                ),
                skipPush: true, // do not send push notification
              ).then((_) {}, onError: (e) {
                debugPrint('[VC] ⚠️ [CustomChatWidget] Error sending call started: $e');
              }),
            );
          } catch (e) {
            debugPrint('[VC] ⚠️ [CustomChatWidget] Error sending call started: $e');
          }

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
      } else if (result is sv_result.Failure) {
        final message = result.error.message;
        debugPrint('[VC] ❌ [CustomChatWidget:_initiateVideoCall] Failed to create call: $message');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create call: $message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        debugPrint('[VC] ⚠️ [CustomChatWidget:_initiateVideoCall] Unexpected getOrCreate result type: ${result.runtimeType}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start call. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
    } finally {
      _startingVideoCall = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = StreamChat.of(context).currentUser?.id ?? '';

    return SafeArea(
      child: Container(
        height: 64,
        padding: const EdgeInsets.only(left: 8, right: 4),
        color: const Color(0xFF0F1828),
        child: Row(
          children: [
            Expanded(
              child: StreamBuilder<ChannelState>(
                stream: widget.channel.state?.channelStateStream,
                initialData: widget.channel.state?.channelState,
                builder: (context, snapshot) {
                  final members = widget.channel.state?.members ?? [];
                  final participants = members
                      .where((m) {
                        final uid = m.userId;
                        return uid != null &&
                            uid.isNotEmpty &&
                            uid != myId &&
                            uid != 'readonly';
                      })
                      .toList()
                    ..sort((a, b) {
                      final an = a.user?.name ?? a.userId ?? '';
                      final bn = b.user?.name ?? b.userId ?? '';
                      return an.compareTo(bn);
                    });

                  if (participants.isEmpty) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Chat',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    );
                  }

                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    itemCount: participants.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final member = participants[index];
                      final u = member.user;
                      final name = u?.name ?? member.userId ?? '';
                      final online = u?.online ?? false;
                      final image = u?.image;
                      return _ChatHeaderParticipantTile(
                        name: name,
                        imageUrl: image,
                        isOnline: online,
                      );
                    },
                  );
                },
              ),
            ),
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
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
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

class _ChatHeaderParticipantTile extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool isOnline;

  const _ChatHeaderParticipantTile({
    required this.name,
    required this.imageUrl,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _ChatHeaderAvatar(url: imageUrl, name: name),
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0F1828),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isOnline ? Colors.green.shade400 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatHeaderAvatar extends StatelessWidget {
  final String? url;
  final String name;

  const _ChatHeaderAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final u = url;
    if (u != null && u.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          u,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _initialCircle(initial),
        ),
      );
    }
    return _initialCircle(initial);
  }

  Widget _initialCircle(String initial) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF2563EB),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
