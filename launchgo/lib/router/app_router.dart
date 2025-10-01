import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import 'package:launchgo/features/documents/domain/entities/document_entity.dart';
import 'package:launchgo/features/documents/presentation/pages/documents_page.dart';
import 'package:launchgo/screens/goals/goals_screen.dart';
import 'package:launchgo/screens/chat/chat_screen.dart';
import 'package:launchgo/screens/courses/courses_screen.dart';
import 'package:launchgo/screens/courses/course_form_screen.dart';
import 'package:launchgo/screens/documents/assignment_form_screen.dart';
import 'package:launchgo/screens/documents/assignments_screen.dart';
import 'package:launchgo/screens/login_screen.dart';
import 'package:launchgo/screens/documents/document_form_screen.dart';
import 'package:launchgo/screens/recaps_screen.dart';
import 'package:launchgo/screens/recap_form_screen.dart';
import 'package:launchgo/models/recap_model.dart';
import 'package:launchgo/screens/schedule/schedule_screen.dart';
import 'package:launchgo/screens/settings_screen.dart';
import 'package:launchgo/screens/schedule/event_form_screen.dart';
import 'package:launchgo/screens/schedule/recurring_event_form_screen.dart';
import 'package:launchgo/models/event_model.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:launchgo/widgets/app_drawer.dart';
import 'package:launchgo/widgets/custom_icon.dart';
import 'package:provider/provider.dart';

class AppRouter {
  final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();
  late final GoRouter router;
  
  AppRouter(AuthService authService) {
    router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/login',
      refreshListenable: authService,
      redirect: (context, state) {
        final isAuthenticated = authService.isAuthenticated;
        final isLoginRoute = state.matchedLocation == '/login';

        if (!isAuthenticated && !isLoginRoute) {
          return '/login';
        }

        if (isAuthenticated && isLoginRoute) {
          return '/schedule';
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
          path: '/chat',
          name: 'chat',
          builder: (context, state) => const ChatScreen(),
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
            final course = state.extra as Map<String, dynamic>;
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
          path: '/edit-event/:eventId',
          name: 'editEvent',
          builder: (context, state) {
            final event = state.extra as Event;
            return EventFormScreen(event: event);
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
            GoRoute(
              path: '/goals',
              name: 'goals',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: GoalsScreen(),
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
        case '/goals':
          return 'Goals';
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
            color: AppColors.accent,
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
            color: AppColors.accent,
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
            color: AppColors.accent,
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
              color: AppColors.accent,
            ),
            label: 'Recaps',
          ),
        );
      }

      // Add Goals tab for all roles
      items.add(
        BottomNavigationBarItem(
          icon: CustomIcon(
            icon: CustomIconPath.goal,
            size: const Size(24, 24),
            color: AppColors.bottomNavUnselected,
          ),
          activeIcon: CustomIcon(
            icon: CustomIconPath.goal,
            size: const Size(24, 24),
            color: AppColors.accent,
          ),
          label: 'Goals',
        ),
      );

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
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/ic_chat.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                themeService.textColor,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () {
              context.push('/chat');
            },
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/ic_alert.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                themeService.textColor,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () {
              // TODO: Handle alert/notifications action
            },
          ),
        ],
      ),
      body: child,
      drawer: const AppDrawer(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _calculateSelectedIndex(context, authService),
        onTap: (index) => _onItemTapped(index, context, authService),
        backgroundColor: AppColors.bottomNavBackground,
        selectedItemColor: AppColors.bottomNavSelected,
        unselectedItemColor: AppColors.bottomNavUnselected,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
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