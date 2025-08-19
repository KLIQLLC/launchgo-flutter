import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:launchgo/features/documents/presentation/pages/documents_page.dart';
import 'package:launchgo/screens/courses_screen.dart';
import 'package:launchgo/screens/login_screen.dart';
import 'package:launchgo/screens/recaps_screen.dart';
import 'package:launchgo/screens/schedule_screen.dart';
import 'package:launchgo/screens/settings_screen.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:launchgo/widgets/app_drawer.dart';
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

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    final themeService = context.watch<ThemeService>();
    
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
        default:
          return 'LaunchGo';
      }
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
        actions: null,
      ),
      body: child,
      drawer: const AppDrawer(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        backgroundColor: const Color(0xFF1A1F2B),
        selectedItemColor: const Color(0xFF7B8CDE),
        unselectedItemColor: Colors.white.withValues(alpha: 0.5),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Courses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Documents',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.summarize),
            label: 'Recaps',
          ),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    switch (location) {
      case '/schedule':
        return 0;
      case '/courses':
        return 1;
      case '/documents':
        return 2;
      case '/recaps':
        return 3;
      default:
        return 0;
    }
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/schedule');
        break;
      case 1:
        context.go('/courses');
        break;
      case 2:
        context.go('/documents');
        break;
      case 3:
        context.go('/recaps');
        break;
    }
  }
}