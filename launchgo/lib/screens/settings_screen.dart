import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:launchgo/services/push_notification_service.dart';
import 'package:launchgo/utils/debug_utils.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final themeService = context.watch<ThemeService>();
    
    return Scaffold(
      backgroundColor: themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeService.backgroundColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            color: themeService.textColor,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeService.textColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          // Profile Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: themeService.borderColor,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: themeService.iconColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authService.currentUser?.displayName ?? 'User',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: themeService.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        authService.currentUser?.email ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: themeService.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Divider(color: themeService.borderColor),
          
          ListTile(
            leading: Icon(Icons.notifications_outlined, color: themeService.iconColor),
            title: Text('Notifications', style: TextStyle(color: themeService.textColor)),
            trailing: Icon(Icons.chevron_right, color: themeService.textTertiaryColor),
            onTap: () {},
          ),
          
          // Debug Section (only in debug mode)
          if (kDebugMode) ...[
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔧 Debug Tools',
                    style: TextStyle(
                      color: themeService.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Token Testing',
                    style: TextStyle(
                      color: themeService.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DebugButton(
                        label: 'Expire Now',
                        onPressed: () async {
                          await DebugUtils.expireTokenNow();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Token expired. Next API call will trigger login'),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                          }
                        },
                      ),
                      _DebugButton(
                        label: 'Expire in 5s',
                        onPressed: () async {
                          await DebugUtils.expireTokenIn(const Duration(seconds: 5));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Token will expire in 5 seconds'),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                          }
                        },
                      ),
                      _DebugButton(
                        label: 'Clear Token',
                        onPressed: () async {
                          await DebugUtils.clearToken();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Token cleared. Next API call will fail'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                      ),
                      _DebugButton(
                        label: 'Corrupt Token',
                        onPressed: () async {
                          await DebugUtils.corruptToken();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Token corrupted. Next API call will fail'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                      ),
                      _DebugButton(
                        label: 'Check Status',
                        onPressed: () async {
                          await DebugUtils.checkTokenStatus();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Check console for token status'),
                                backgroundColor: AppColors.info,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Push Notifications',
                    style: TextStyle(
                      color: themeService.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FCMTokenDisplay(),
                  const SizedBox(height: 8),
                  _DebugButton(
                    label: 'Init Notifications',
                    onPressed: () async {
                      try {
                        await PushNotificationService.instance.initialize();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Notification service initialized'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to initialize: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            Divider(color: themeService.borderColor),
          ],
          
        ],
      ),
    );
  }
}

class _DebugButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  
  const _DebugButton({
    required this.label,
    required this.onPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.buttonGrey,
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _FCMTokenDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pushNotificationService = context.watch<PushNotificationService?>();
    final themeService = context.watch<ThemeService>();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeService.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeService.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications,
                size: 16,
                color: themeService.textSecondaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'FCM Token',
                style: TextStyle(
                  color: themeService.textSecondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (pushNotificationService?.fcmToken != null)
                IconButton(
                  icon: Icon(
                    Icons.copy,
                    size: 16,
                    color: themeService.textSecondaryColor,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pushNotificationService?.fcmToken ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('FCM Token copied to clipboard'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeService.backgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              pushNotificationService?.fcmToken ?? 'No token available',
              style: TextStyle(
                color: themeService.textColor,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: (pushNotificationService?.isInitialized ?? false)
                      ? AppColors.success 
                      : AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                (pushNotificationService?.isInitialized ?? false)
                    ? 'Notifications enabled' 
                    : 'Notifications disabled',
                style: TextStyle(
                  color: themeService.textSecondaryColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}