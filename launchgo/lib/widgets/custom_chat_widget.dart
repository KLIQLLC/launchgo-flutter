import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import '../services/auth_service.dart';
import 'dart:async';

class CustomChatWidget extends StatelessWidget {
  final StreamChatClient client;
  final Channel channel;

  const CustomChatWidget({
    Key? key,
    required this.client,
    required this.channel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamChannel(
      channel: channel,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: _CustomChatAppBar(channel: channel),
        ),
        body: const Column(
          children: <Widget>[
            Expanded(
              child: StreamMessageListView(),
            ),
            StreamMessageInput(),
          ],
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
      displayName = selectedStudent?.name ?? 'Student';
      displayAvatar = selectedStudent?.avatarUrl ?? '';
      otherUserId = selectedStudent?.id;
    }
  }

  void _subscribeToChannelEvents() {
    _channelSubscription = widget.channel.on().listen((event) {
      if (event.type == 'user.presence.changed' ||
          event.type == 'user.updated' ||
          event.type == 'member.updated') {
        _updateOnlineStatus();
      }
    });
  }

  void _updateOnlineStatus() {
    final members = widget.channel.state?.members ?? [];
    final otherMember = members.firstWhere(
      (m) => m.userId == otherUserId,
      orElse: () => members.isNotEmpty ? members.first : Member(userId: '', user: null),
    );
    setState(() {
      isOnline = otherMember.user?.online ?? false;
    });
  }

  @override
  void dispose() {
    _channelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.black,
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
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
