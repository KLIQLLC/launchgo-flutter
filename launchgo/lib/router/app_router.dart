import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import 'package:launchgo/widgets/chat_badge_widget.dart';
import 'package:launchgo/features/documents/domain/entities/document_entity.dart';
import 'package:launchgo/features/documents/presentation/pages/documents_page.dart';
import 'package:launchgo/screens/chat/refactored_chat_screen.dart';
import 'package:launchgo/screens/courses/courses_screen.dart';
import 'package:launchgo/screens/courses/course_form_screen.dart';
import 'package:launchgo/screens/documents/assignment_form_screen.dart';
import 'package:launchgo/screens/documents/assignments_screen.dart';
import 'package:launchgo/screens/login_screen.dart';
import 'package:launchgo/screens/documents/document_form_screen.dart';
import 'package:launchgo/features/recaps/presentation/pages/recaps_page.dart';
import 'package:launchgo/features/recaps/presentation/pages/recap_form_page.dart';
import 'package:launchgo/models/recap_model.dart';
import 'package:launchgo/screens/schedule/schedule_screen.dart';
import 'package:launchgo/screens/settings_screen.dart';
import 'package:launchgo/screens/notifications_screen.dart';
import 'package:launchgo/screens/schedule/event_form_screen.dart';
import 'package:launchgo/screens/schedule/recurring_event_form_screen.dart';
import 'package:launchgo/models/event_model.dart';
import 'package:launchgo/utils/event_helper.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:launchgo/widgets/app_drawer.dart';
import 'package:launchgo/widgets/custom_icon.dart';
import 'package:launchgo/widgets/notification_badge_widget.dart';
import 'package:launchgo/screens/video_call/mentor_video_chat_screen.dart';
import 'package:launchgo/screens/video_call/student_video_chat_screen.dart';

class AppRouter {
  final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();
  late final GoRouter router;
  
  // Expose navigator key for push navigation
  GlobalKey<NavigatorState> get navigatorKey => _rootNavigatorKey;
  
  AppRouter(AuthService authService) {
    router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/login',
      refreshListenable: authService,
      redirect: (context, state) {
        // During cold start / CallKit wakeup, auth may still be initializing.
        // Redirecting too early can send the user to /login even if a valid token
        // exists but hasn't been loaded yet.
        if (!authService.isInitialized) {
          return null;
        }

        final isAuthenticated = authService.isAuthenticated;
        final isLoginRoute = state.matchedLocation == '/login';

        if (!isAuthenticated && !isLoginRoute) {
          return '/login';
        }

        if (isAuthenticated && isLoginRoute) {
          return '/schedule';
        }

        if (state.uri.path == '/goals') {
          return isAuthenticated ? '/schedule' : '/login';
        }

        // Prevent unauthorized access based on role permissions
        if (isAuthenticated) {
          // Check for document and course creation/edit routes
          if ((state.matchedLocation == '/new-document' && !authService.permissions.canCreateDocuments) ||
              (state.matchedLocation == '/new-course' && !authService.permissions.canCreateDocuments) ||
              (state.matchedLocation.startsWith('/edit-document/') && !authService.permissions.canEditDocuments) ||
              (state.matchedLocation.startsWith('/edit-course/') && !authService.permissions.canEditDocuments)) {
            return '/courses'; // Redirect students away from document/course forms
          }
          
          final redirect = authService.permissions.getRedirectRoute(state.matchedLocation);
          if (redirect != null) {
            return redirect;
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/chat',
          name: 'chat',
          builder: (context, state) => const RefactoredChatScreen(),
        ),
        GoRoute(
          path: '/new-document',
          name: 'newDocument',
          builder: (context, state) => const DocumentFormScreen(),
        ),
        GoRoute(
          path: '/edit-document/:documentId',
          name: 'editDocument',
          builder: (context, state) {
            final document = state.extra as DocumentEntity;
            return DocumentFormScreen(
              mode: DocumentScreenMode.edit,
              document: document,
            );
          },
        ),
        GoRoute(
          path: '/new-course',
          name: 'newCourse',
          builder: (context, state) => const CourseFormScreen(),
        ),
        GoRoute(
          path: '/edit-course/:courseId',
          name: 'editCourse',
          builder: (context, state) {
            final course = state.extra as Map<String, dynamic>;
            return CourseFormScreen(course: course);
          },
        ),
        GoRoute(
          path: '/course/:courseId/assignments',
          name: 'courseAssignments',
          builder: (context, state) {
            final courseId = state.pathParameters['courseId']!;
            
            // Try to get course from extra data (when navigating from course card)
            Map<String, dynamic> course;
            if (state.extra != null) {
              course = state.extra as Map<String, dynamic>;
            } else {
              // Create minimal course data when navigating via URL (from notifications)
              course = {
                'id': courseId,
                'code': 'Unknown', // Will be updated when assignments load
                'name': 'Course Assignments',
                'assignments': [], // Will be populated when screen loads
              };
            }
            
            return AssignmentsScreen(course: course);
          },
        ),
        GoRoute(
          path: '/course/:courseId/assignments/new',
          name: 'newAssignment',
          builder: (context, state) {
            final course = state.extra as Map<String, dynamic>;
            return AssignmentFormScreen(course: course);
          },
        ),
        GoRoute(
          path: '/course/:courseId/assignments/:assignmentId/edit',
          name: 'editAssignment',
          builder: (context, state) {
            final extras = state.extra as Map<String, dynamic>;
            final course = extras['course'] as Map<String, dynamic>;
            final assignment = extras['assignment'] as Map<String, dynamic>;
            return AssignmentFormScreen(
              course: course,
              assignment: assignment,
            );
          },
        ),
        GoRoute(
          path: '/new-event',
          name: 'newEvent',
          builder: (context, state) => const EventFormScreen(),
        ),
        GoRoute(
          path: '/new-recurring-event',
          name: 'newRecurringEvent',
          builder: (context, state) => const RecurringEventFormScreen(),
        ),
        GoRoute(
          path: '/event/:eventId',
          name: 'event',
          builder: (context, state) {
            final event = state.extra as Event;
            final permissions = context.read<AuthService>().permissions;
            final isReadOnly = !permissions.canEditEvents || !EventHelper.canDeleteEvent(event);
            return EventFormScreen(event: event, isReadOnly: isReadOnly);
          },
        ),
        GoRoute(
          path: '/recurring-event/:eventId',
          name: 'recurringEvent',
          builder: (context, state) {
            final event = state.extra as Event;
            final permissions = context.read<AuthService>().permissions;
            final isReadOnly = !permissions.canEditEvents || !EventHelper.canDeleteEvent(event);
            return RecurringEventFormScreen(event: event, isReadOnly: isReadOnly);
          },
        ),
        GoRoute(
          path: '/new-recap',
          name: 'newRecap',
          builder: (context, state) => const RecapFormScreen(),
        ),
        GoRoute(
          path: '/edit-recap/:recapId',
          name: 'editRecap',
          builder: (context, state) {
            final recap = state.extra as Recap;
            return RecapFormScreen(recap: recap);
          },
        ),
        // Mentor video call screen (outgoing calls)
        GoRoute(
          path: '/mentor-video-chat/:callId',
          name: 'mentor-video-chat',
          builder: (context, state) {
            final callId = state.pathParameters['callId']!;
            final recipientName = state.uri.queryParameters['recipientName'];

            return MentorVideoChatScreen(
              callId: callId,
              recipientName: recipientName,
            );
          },
        ),
        // Student video call screen (incoming calls)
        GoRoute(
          path: '/student-video-chat/:callId',
          name: 'student-video-chat',
          builder: (context, state) {
            final callId = state.pathParameters['callId']!;
            final callerName = state.uri.queryParameters['callerName'];
            final autoAccept = state.uri.queryParameters['autoAccept'] == 'true';

            return StudentVideoChatScreen(
              callId: callId,
              callerName: callerName,
              autoAccept: autoAccept,
            );
          },
        ),
        // OLD routes - kept for compatibility during transition
        // GoRoute(
        //   path: '/video-call/:callId',
        //   name: 'video-call',
        //   builder: (context, state) {
        //     final callId = state.pathParameters['callId']!;
        //     final recipientName = state.uri.queryParameters['recipientName'] ?? 'User';
        //     final callAlreadyJoined = state.uri.queryParameters['callAlreadyJoined'] == 'true';
        //     return VideoCallScreen(
        //       callId: callId,
        //       recipientName: recipientName,
        //       callAlreadyJoined: callAlreadyJoined,
        //     );
        //   },
        // ),
        // GoRoute(
        //   path: '/incoming-call/:callId',
        //   name: 'incoming-call',
        //   builder: (context, state) {
        //     final callId = state.pathParameters['callId']!;
        //     final callerName = state.uri.queryParameters['callerName'] ?? 'Unknown';
        //     return IncomingCallScreen(
        //       callId: callId,
        //       callerName: callerName,
        //     );
        //   },
        // ),
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => 
              ScaffoldWithBottomNavBar(child: child),
          routes: [
            GoRoute(
              path: '/schedule',
              name: 'schedule',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ScheduleScreen(),
              ),
            ),
            GoRoute(
              path: '/courses',
              name: 'courses',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: CoursesScreen(),
              ),
            ),
            GoRoute(
              path: '/documents',
              name: 'documents',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: DocumentsPage(),
              ),
            ),
            GoRoute(
              path: '/recaps',
              name: 'recaps',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: RecapsScreen(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ScaffoldWithBottomNavBar extends StatelessWidget {
  const ScaffoldWithBottomNavBar({
    required this.child,
    super.key,
  });

  final Widget child;
  
  static const Color _selectedTabColor = Color(0xFFDC8862);

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    final themeService = context.watch<ThemeService>();
    final authService = context.watch<AuthService>();
    
    String getTitle() {
      switch (location) {
        case '/schedule':
          return 'Schedule';
        case '/courses':
          return 'Courses';
        case '/documents':
          return 'Documents';
        case '/recaps':
          return 'Session Recaps';
        default:
          return 'launchgo';
      }
    }
    
    // Build navigation items based on user role
    List<BottomNavigationBarItem> buildNavigationItems() {
      List<BottomNavigationBarItem> items = [
        BottomNavigationBarItem(
          icon: CustomIcon(
            icon: CustomIconPath.schedule,
            size: const Size(24, 24),
            color: AppColors.bottomNavUnselected,
          ),
          activeIcon: CustomIcon(
            icon: CustomIconPath.schedule,
            size: const Size(24, 24),
            color: _selectedTabColor,
          ),
          label: 'Schedule',
        ),
        BottomNavigationBarItem(
          icon: CustomIcon(
            icon: CustomIconPath.course,
            size: const Size(24, 24),
            color: AppColors.bottomNavUnselected,
          ),
          activeIcon: CustomIcon(
            icon: CustomIconPath.course,
            size: const Size(24, 24),
            color: _selectedTabColor,
          ),
          label: 'Courses',
        ),
        BottomNavigationBarItem(
          icon: CustomIcon(
            icon: CustomIconPath.document,
            size: const Size(24, 24),
            color: AppColors.bottomNavUnselected,
          ),
          activeIcon: CustomIcon(
            icon: CustomIconPath.document,
            size: const Size(24, 24),
            color: _selectedTabColor,
          ),
          label: 'Documents',
        ),
      ];

      // Add Recaps tab based on permissions
      if (authService.permissions.canShowRecapsTab) {
        items.add(
          BottomNavigationBarItem(
            icon: CustomIcon(
              icon: CustomIconPath.recap,
              size: const Size(24, 24),
              color: AppColors.bottomNavUnselected,
            ),
            activeIcon: CustomIcon(
              icon: CustomIconPath.recap,
              size: const Size(24, 24),
              color: _selectedTabColor,
            ),
            label: 'Recaps',
          ),
        );
      }

      return items;
    }
    
    return Scaffold(
      backgroundColor: themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeService.backgroundColor,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu, 
              color: themeService.textColor,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          getTitle(),
          style: TextStyle(
            color: themeService.textColor,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          // Chat icon with unread badge
          ChatBadgeWidget(
            onPressed: () {
              context.push('/chat');
            },
          ),
          NotificationBadgeWidget(
            onPressed: () {
              context.push('/notifications');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: child,
      drawer: const AppDrawer(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _calculateSelectedIndex(context, authService),
        onTap: (index) => _onItemTapped(index, context, authService),
        backgroundColor: AppColors.bottomNavBackground,
        selectedItemColor: _selectedTabColor,
        unselectedItemColor: AppColors.bottomNavUnselected,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: buildNavigationItems(),
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context, AuthService authService) {
    final String location = GoRouterState.of(context).matchedLocation;
    
    // Use permissions service to get the correct index
    final index = authService.permissions.getNavigationIndex(location);
    return index ?? 0; // Default to first tab if not found
  }

  void _onItemTapped(int index, BuildContext context, AuthService authService) {
    // Use permissions service to get the correct route for the index
    final route = authService.permissions.getRouteForIndex(index);
    if (route != null) {
      context.go(route);
    }
  }
}