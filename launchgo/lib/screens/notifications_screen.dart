import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:launchgo/models/notification_model.dart';
import 'package:launchgo/services/notifications_api_service.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationsApiService? _notificationsService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _notificationsService != null) {
        _notificationsService!.fetchNotifications();
      }
    });
  }

  @override
  void dispose() {
    // Refresh notifications when leaving the screen to update badge (async to avoid framework lock)
    if (_notificationsService != null) {
      Future.microtask(() => _notificationsService!.fetchNotifications());
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
      _notificationsService = context.read<NotificationsApiService>();
    }
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
            Icons.close,
            color: themeService.textColor,
          ),
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

          return Column(
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
              // Mark all as read button - positioned like Add Course button
              if (notifications.where((n) => !n.isRead).isNotEmpty)
                _buildMarkAllReadButton(themeService),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(int notificationCount, ThemeService themeService) {
    final unreadCount = _notificationsService?.unreadCount ?? 0;
    
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
        decoration: BoxDecoration(
          color: themeService.cardColor,
          border: Border(
            top: BorderSide(
              color: themeService.borderColor,
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
              color: const Color(0xFF3F4653),
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
      decoration: BoxDecoration(
        color: themeService.backgroundColor,
        border: Border(
          top: BorderSide(
            color: themeService.borderColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () async {
              try {
                await _notificationsService?.markAllAsRead();
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
              backgroundColor: AppColors.buttonPrimary,
              foregroundColor: const Color(0xFF1A1F2B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Mark all as read',
              style: TextStyle(
                color: Color(0xFF1A1F2B),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
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
            onPressed: () => _notificationsService?.fetchNotifications(),
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
        await _notificationsService?.markAsRead(notification.id);
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
    
    // Navigate based on notification type and metadata
    if (mounted) {
      await _navigateBasedOnNotification(notification);
    }
  }

  Future<void> _navigateBasedOnNotification(NotificationModel notification) async {
    try {
      switch (notification.type) {
        case 'update-document':
        case 'create-document':
          // Extract document ID and optional cell reference from metadata
          final documentId = notification.metadata?['documentId'] as String?;
          final cellId = notification.metadata?['cellId'] as String?;
          final lineNumber = notification.metadata?['lineNumber'] as int?;
          final sectionId = notification.metadata?['sectionId'] as String?;
          final semesterId = notification.metadata?['semesterId'] as String?;
          final studentId = notification.metadata?['studentId'] as String?;
          
          if (documentId != null) {
            // Switch semester and student if needed before navigation
            await _switchContextIfNeeded(semesterId, studentId);
            
            // Always navigate to documents list and scroll to specific document
            String url = '/documents?scrollToDocumentId=$documentId';
            List<String> queryParams = ['scrollToDocumentId=$documentId'];
            
            // Add cell/line/section parameters for highlighting
            if (cellId != null) {
              queryParams.add('cellId=$cellId');
            }
            if (lineNumber != null) {
              queryParams.add('line=$lineNumber');
            }
            if (sectionId != null) {
              queryParams.add('section=$sectionId');
            }
            
            url = '/documents?${queryParams.join('&')}';
            if (mounted) {
              context.go(url);
            }
          } else {
            // Fallback to documents list if no specific document ID
            if (mounted) {
              context.go('/documents');
            }
          }
          break;
          
        case 'create-assignment':
        case 'update-assignment':
          // Navigate to schedule screen where assignments are displayed
          context.go('/schedule');
          break;
          
        case 'create-event':
        case 'update-event':
          // Navigate to schedule screen where events are displayed
          context.go('/schedule');
          break;
          
        case 'upload-attachment':
          // Extract assignment and course information from metadata
          final assignmentId = notification.metadata?['assignmentId'] as String?;
          final courseId = notification.metadata?['courseId'] as String?;
          final semesterId = notification.metadata?['semesterId'] as String?;
          final studentId = notification.metadata?['studentId'] as String?;
          final cellId = notification.metadata?['cellId'] as String?;
          final lineNumber = notification.metadata?['lineNumber'] as int?;
          final sectionId = notification.metadata?['sectionId'] as String?;
          
          if (assignmentId != null && courseId != null) {
            // Switch semester and student if needed before navigation
            await _switchContextIfNeeded(semesterId, studentId);
            
            // Navigate to course assignments and scroll to specific assignment
            String url = '/course/$courseId/assignments?scrollToAssignmentId=$assignmentId';
            List<String> queryParams = ['scrollToAssignmentId=$assignmentId'];
            
            // Add cell/line/section parameters for highlighting
            if (cellId != null) {
              queryParams.add('cellId=$cellId');
            }
            if (lineNumber != null) {
              queryParams.add('line=$lineNumber');
            }
            if (sectionId != null) {
              queryParams.add('section=$sectionId');
            }
            
            url = '/course/$courseId/assignments?${queryParams.join('&')}';
            if (mounted) {
              context.go(url);
            }
          } else {
            // Fallback: try document navigation or just go to courses
            final documentId = notification.metadata?['documentId'] as String?;
            if (documentId != null) {
              // Switch context if needed before document navigation
              await _switchContextIfNeeded(semesterId, studentId);
              if (mounted) {
                context.go('/documents?scrollToDocumentId=$documentId');
              }
            } else if (mounted) {
              context.go('/courses');
            }
          }
          break;
          
        case 'create-course':
          // Navigate to courses screen
          context.go('/courses');
          break;
          
        default:
          // For unknown notification types, stay on notifications screen
          // or navigate to a default screen
          break;
      }
    } catch (e) {
      debugPrint('Error navigating from notification: $e');
      // If navigation fails, show error but don't crash
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to navigate to content'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
      case 'create-document':
      case 'update-document':
        return 'assets/icons/ic_document.svg';
      case 'create-event':
      case 'update-event':
        return 'assets/icons/ic_schedule.svg';
      case 'upload-attachment':
        return 'assets/icons/ic_upload.svg';
      case 'create-assignment':
      case 'update-assignment':
      case 'create-course':
        return 'assets/icons/ic_course.svg';
      default:
        return 'assets/icons/ic_alert.svg';
    }
  }

  /// Switch semester and student context if needed before navigation
  Future<void> _switchContextIfNeeded(String? semesterId, String? studentId) async {
    final authService = context.read<AuthService>();
    
    bool contextChanged = false;
    
    try {
      // Switch student if needed (for mentors)
      if (studentId != null && 
          authService.isMentor && 
          authService.selectedStudentId != studentId) {
        debugPrint('🔄 Switching to student: $studentId');
        await authService.selectStudent(studentId);
        contextChanged = true;
      }
      
      // Switch semester if needed
      if (semesterId != null && 
          authService.selectedSemesterId != semesterId) {
        debugPrint('🔄 Switching to semester: $semesterId');
        await authService.selectSemester(semesterId);
        contextChanged = true;
      }
      
      // Wait for auth service state to propagate if context changed
      if (contextChanged) {
        debugPrint('📍 Context switched, waiting for state propagation...');
        // Wait for the next frame to ensure notifyListeners() has been processed
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Verify the context has actually changed
        bool contextApplied = true;
        if (studentId != null && authService.isMentor) {
          contextApplied = contextApplied && authService.selectedStudentId == studentId;
        }
        if (semesterId != null) {
          contextApplied = contextApplied && authService.selectedSemesterId == semesterId;
        }
        
        if (!contextApplied) {
          debugPrint('⚠️ Context change not fully applied, waiting longer...');
          // Fallback: wait a bit longer if state hasn't propagated
          await Future.delayed(const Duration(milliseconds: 200));
        }
        
        debugPrint('✅ Context switching complete');
      }
    } catch (e) {
      debugPrint('❌ Error switching context: $e');
      // Continue with navigation even if context switch fails
    }
  }
}