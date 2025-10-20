import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:launchgo/models/notification_model.dart';
import 'package:launchgo/services/notifications_api_service.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:launchgo/theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationsApiService _notificationsService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationsService.fetchNotifications();
    });
  }

  @override
  void dispose() {
    // Refresh notifications when leaving the screen to update badge (async to avoid framework lock)
    Future.microtask(() => _notificationsService.fetchNotifications());
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notificationsService = context.read<NotificationsApiService>();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    
    return Scaffold(
      backgroundColor: themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeService.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: themeService.textColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: themeService.textColor,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: Consumer<NotificationsApiService>(
        builder: (context, notificationsService, child) {
          if (notificationsService.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (notificationsService.error != null) {
            return _buildErrorState(notificationsService.error!, themeService);
          }

          final notifications = notificationsService.notifications;
          
          if (notifications.isEmpty) {
            return _buildEmptyState(themeService);
          }

          return Scaffold(
            body: Column(
              children: [
                _buildHeader(notifications.length, themeService),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => notificationsService.refresh(),
                    child: ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return _buildNotificationTile(notification, themeService);
                      },
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: notifications.where((n) => !n.isRead).isNotEmpty
                ? _buildMarkAllReadButton(themeService)
                : null,
          );
        },
      ),
    );
  }

  Widget _buildHeader(int notificationCount, ThemeService themeService) {
    final unreadCount = _notificationsService.unreadCount;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            'You have $unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
            style: TextStyle(
              color: themeService.textColor.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(NotificationModel notification, ThemeService themeService) {
    return GestureDetector(
      onTap: () => _handleNotificationTap(notification),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF101929),
          border: Border(
            top: BorderSide(
              color: Color(0xFF374151),
              width: 1.0,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Icon with unread indicator
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFF3E4653),
            ),
            child: Center(
              child: Stack(
                children: [
                  SvgPicture.asset(
                    _getNotificationIcon(notification.type),
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      themeService.textColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Notification content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        color: themeService.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!notification.isRead) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: TextStyle(
                    color: themeService.textColor.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTimeAgo(notification.createdAt),
                  style: TextStyle(
                    color: themeService.textColor.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildMarkAllReadButton(ThemeService themeService) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            try {
              await _notificationsService.markAllAsRead();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF101929),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Mark all as read',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeService themeService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icons/ic_alert.svg',
            width: 64,
            height: 64,
            colorFilter: ColorFilter.mode(
              themeService.textColor.withValues(alpha: 0.3),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: TextStyle(
              color: themeService.textColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              color: themeService.textColor.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, ThemeService themeService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: themeService.textColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading notifications',
            style: TextStyle(
              color: themeService.textColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: themeService.textColor.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _notificationsService.fetchNotifications(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(NotificationModel notification) async {
    // Mark notification as read if it's unread
    if (!notification.isRead) {
      try {
        await _notificationsService.markAsRead(notification.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error marking notification as read: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
    
    // TODO: Add navigation based on notification type/metadata
    // For now, just mark as read
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  String _getNotificationIcon(String type) {
    switch (type) {
      case 'update-document':
        return 'assets/icons/ic_document.svg';
      case 'update-event':
        return 'assets/icons/ic_schedule.svg';
      case 'upload':
      case 'attachment':
        return 'assets/icons/ic_upload.svg';
      default:
        return 'assets/icons/ic_alert.svg';
    }
  }
}