import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import '../services/auth_service.dart';
import '../services/chat/stream_chat_service.dart';
import '../services/theme_service.dart';
import 'badge_icon.dart';

/// Widget that displays chat icon with unread message badge
class ChatBadgeWidget extends StatelessWidget {
  final VoidCallback onPressed;

  const ChatBadgeWidget({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<StreamChatService, AuthService>(
      builder: (context, streamChatService, authService, _) {
        final themeService = context.watch<ThemeService>();
        
        // Determine user type and selected student
        final isMentor = authService.userInfo?.isMentor == true;
        final selectedStudentId = authService.selectedStudentId;
        
        return Transform.translate(
          offset: const Offset(20, 0),
          child: IconButton(
            padding: const EdgeInsets.all(8.0),
            constraints: const BoxConstraints(),
            icon: _buildBadgeIcon(
              streamChatService,
              themeService,
              isMentor,
              selectedStudentId,
            ),
            onPressed: onPressed,
          ),
        );
      },
    );
  }

  Widget _buildBadgeIcon(
    StreamChatService streamChatService,
    ThemeService themeService,
    bool isMentor,
    String? selectedStudentId,
  ) {
    if (isMentor && selectedStudentId != null) {
      // For mentors, listen to specific student channel updates
      return StreamBuilder<int>(
        stream: streamChatService.getUnreadCountStreamForStudent(selectedStudentId),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;
          debugPrint('🎯 UI Badge: Mentor - Student: $selectedStudentId, Unread: $unreadCount');
          
          return _createBadgeIcon(themeService, unreadCount);
        },
      );
    } else {
      // For students, listen to user stream
      return StreamBuilder<OwnUser?>(
        stream: streamChatService.client.state.currentUserStream,
        builder: (context, userSnapshot) {
          final currentUser = userSnapshot.data;
          final unreadCount = currentUser?.totalUnreadCount ?? 0;
          debugPrint('🎯 UI Badge: Student - Unread: $unreadCount');
          
          return _createBadgeIcon(themeService, unreadCount);
        },
      );
    }
  }

  Widget _createBadgeIcon(ThemeService themeService, int unreadCount) {
    return BadgeIcon(
      icon: SvgPicture.asset(
        'assets/icons/ic_chat.svg',
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(
          themeService.textColor,
          BlendMode.srcIn,
        ),
      ),
      count: unreadCount,
      showBadge: unreadCount > 0,
    );
  }
}