import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../services/notifications_api_service.dart';
import '../services/theme_service.dart';

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
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.asset(
                  'assets/icons/ic_alert.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    themeService.textColor,
                    BlendMode.srcIn,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF6B2024),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: onPressed,
          ),
        );
      },
    );
  }
}