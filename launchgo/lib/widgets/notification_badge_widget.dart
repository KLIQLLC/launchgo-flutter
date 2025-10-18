import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../services/notifications_api_service.dart';
import '../services/theme_service.dart';
import 'badge_icon.dart';

/// Widget that displays notification alert icon with unread notification badge
class NotificationBadgeWidget extends StatelessWidget {
  final VoidCallback onPressed;

  const NotificationBadgeWidget({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationsApiService>(
      builder: (context, notificationsService, _) {
        final themeService = context.watch<ThemeService>();
        final unreadCount = notificationsService.unreadCount;
        
        return Transform.translate(
          offset: const Offset(6, 0),
          child: IconButton(
            padding: const EdgeInsets.all(8.0),
            constraints: const BoxConstraints(),
            icon: BadgeIcon(
              icon: SvgPicture.asset(
                'assets/icons/ic_alert.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  themeService.textColor,
                  BlendMode.srcIn,
                ),
              ),
              count: unreadCount,
              showBadge: unreadCount > 0,
            ),
            onPressed: onPressed,
          ),
        );
      },
    );
  }
}