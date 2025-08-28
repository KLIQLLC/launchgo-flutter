import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:launchgo/features/documents/domain/entities/document_entity.dart';
import 'package:launchgo/features/documents/presentation/pages/documents_page.dart';
import 'package:launchgo/screens/chat_screen.dart';
import 'package:launchgo/screens/courses_screen.dart';
import 'package:launchgo/screens/login_screen.dart';
import 'package:launchgo/screens/document_form_screen.dart';
import 'package:launchgo/screens/recaps_screen.dart';
import 'package:launchgo/screens/schedule_screen.dart';
import 'package:launchgo/screens/settings_screen.dart';
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
          // Check for document creation/edit routes
          if ((state.matchedLocation == '/new-document' && !authService.permissions.canCreateDocuments) ||
              (state.matchedLocation.startsWith('/edit-document/') && !authService.permissions.canEditDocuments)) {
            return '/documents'; // Redirect students away from document forms
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
              path: '/chat',
              name: 'chat',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ChatScreen(),
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
          return 'Documents & Study Guides';
        case '/recaps':
          return 'Recaps';
        case '/chat':
          return 'Chat';
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
            color: Colors.white.withValues(alpha: 0.5),
          ),
          activeIcon: CustomIcon(
            icon: CustomIconPath.schedule,
            size: const Size(24, 24),
            color: const Color(0xFF7B8CDE),
          ),
          label: 'Schedule',
        ),
        BottomNavigationBarItem(
          icon: CustomIcon(
            icon: CustomIconPath.course,
            size: const Size(24, 24),
            color: Colors.white.withValues(alpha: 0.5),
          ),
          activeIcon: CustomIcon(
            icon: CustomIconPath.course,
            size: const Size(24, 24),
            color: const Color(0xFF7B8CDE),
          ),
          label: 'Courses',
        ),
        BottomNavigationBarItem(
          icon: CustomIcon(
            icon: CustomIconPath.document,
            size: const Size(24, 24),
            color: Colors.white.withValues(alpha: 0.5),
          ),
          activeIcon: CustomIcon(
            icon: CustomIconPath.document,
            size: const Size(24, 24),
            color: const Color(0xFF7B8CDE),
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
              color: Colors.white.withValues(alpha: 0.5),
            ),
            activeIcon: CustomIcon(
              icon: CustomIconPath.recap,
              size: const Size(24, 24),
              color: const Color(0xFF7B8CDE),
            ),
            label: 'Recaps',
          ),
        );
      }

      // Add Chat tab for all roles
      items.add(
        BottomNavigationBarItem(
          icon: CustomIcon(
            icon: CustomIconPath.chat,
            size: const Size(24, 24),
            color: Colors.white.withValues(alpha: 0.5),
          ),
          activeIcon: CustomIcon(
            icon: CustomIconPath.chat,
            size: const Size(24, 24),
            color: const Color(0xFF7B8CDE),
          ),
          label: 'Chat',
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
                // Badge with unread count
                Positioned(
                  right: -10,
                  top: -14,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: const Center(
                      child: Text(
                        '3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
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
        backgroundColor: const Color(0xFF1A1F2B),
        selectedItemColor: const Color(0xFF7B8CDE),
        unselectedItemColor: Colors.white.withValues(alpha: 0.5),
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