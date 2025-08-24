import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:launchgo/features/documents/presentation/pages/documents_page.dart';
import 'package:launchgo/screens/chat_screen.dart';
import 'package:launchgo/screens/courses_screen.dart';
import 'package:launchgo/screens/login_screen.dart';
import 'package:launchgo/screens/new_document_screen.dart';
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
          builder: (context, state) => const NewDocumentScreen(),
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
      floatingActionButton: location == '/documents' ? FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to new document screen
          final result = await context.push('/new-document');
          if (result == true && context.mounted) {
            // Refresh documents list if document was created successfully
            // This will be handled by the documents page's refresh logic
          }
        },
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1F2B),
        icon: const Icon(Icons.add),
        label: const Text('New Document'),
      ) : null,
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
        items: [
          BottomNavigationBarItem(
            icon: CustomIcon(
              icon: CustomIconPath.schedule,
              size: const Size(24, 24),
              color: Colors.white.withValues(alpha: 0.5), // Unselected color
            ),
            activeIcon: CustomIcon(
              icon: CustomIconPath.schedule,
              size: const Size(24, 24),
              color: const Color(0xFF7B8CDE), // Selected color
            ),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: CustomIcon(
              icon: CustomIconPath.course,
              size: const Size(24, 24),
              color: Colors.white.withValues(alpha: 0.5), // Unselected color
            ),
            activeIcon: CustomIcon(
              icon: CustomIconPath.course,
              size: const Size(24, 24),
              color: const Color(0xFF7B8CDE), // Selected color
            ),
            label: 'Courses',
          ),
          BottomNavigationBarItem(
            icon: CustomIcon(
              icon: CustomIconPath.document,
              size: const Size(24, 24),
              color: Colors.white.withValues(alpha: 0.5), // Unselected color
            ),
            activeIcon: CustomIcon(
              icon: CustomIconPath.document,
              size: const Size(24, 24),
              color: const Color(0xFF7B8CDE), // Selected color
            ),
            label: 'Documents',
          ),
          BottomNavigationBarItem(
            icon: CustomIcon(
              icon: CustomIconPath.recap,
              size: const Size(24, 24),
              color: Colors.white.withValues(alpha: 0.5), // Unselected color
            ),
            activeIcon: CustomIcon(
              icon: CustomIconPath.recap,
              size: const Size(24, 24),
              color: const Color(0xFF7B8CDE), // Selected color
            ),
            label: 'Recaps',
          ),
          BottomNavigationBarItem(
            icon: CustomIcon(
              icon: CustomIconPath.chat,
              size: const Size(24, 24),
              color: Colors.white.withValues(alpha: 0.5), // Unselected color
            ),
            activeIcon: CustomIcon(
              icon: CustomIconPath.chat,
              size: const Size(24, 24),
              color: const Color(0xFF7B8CDE), // Selected color
            ),
            label: 'Chat',
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
      case '/chat':
        return 4;
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
      case 4:
        context.go('/chat');
        break;
    }
  }
}