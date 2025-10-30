import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/services/chat/stream_chat_service.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:launchgo/theme/app_colors.dart';
import 'package:launchgo/widgets/cupertino_dropdown.dart';
import 'package:launchgo/widgets/version_environment_widget.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // Constants
  static const double _drawerHeaderHeight = 210.0;
  static const double _logoHeight = 50.0;
  static const double _logoWidth = 120.0;
  static const double _horizontalPadding = 16.0;
  static const double _itemIndentPadding = 16.0;

  @override
  void initState() {
    super.initState();
    // Semesters are now loaded automatically via loadUserInfo()
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final themeService = context.watch<ThemeService>();
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return Drawer(
      backgroundColor: AppColors.darkCard,
      child: Column(
        children: [
          // Drawer Header with solid color
          Container(
            height: _drawerHeaderHeight,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.darkCard,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    SvgPicture.asset(
                      'assets/images/launchgo_logo.svg',
                      height: _logoHeight,
                      width: _logoWidth,
                      fit: BoxFit.contain,
                      colorFilter: null
                    ),
                    const SizedBox(height: 12),
                    // User info
                    Text(
                      authService.userInfo?.name ?? authService.currentUser?.displayName ?? 'Unknown',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      authService.userInfo?.email ?? authService.currentUser?.email ?? '',
                      style: const TextStyle(
                        color: AppColors.textWhite70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                  child: Divider(color: themeService.borderColor, height: 1),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(_horizontalPadding, _horizontalPadding, _horizontalPadding, 8),
                  child: Text(
                    'Semester',
                    style: TextStyle(
                      color: themeService.textTertiaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Semester Dropdown - always visible for all roles
                Padding(
                  padding: const EdgeInsets.only(left: 32, right: 80),
                  child: Consumer<AuthService>(
                    builder: (context, authService, child) {
                      final selectedSemester = authService.getSelectedSemester();
                      final semesterNames = authService.semesters.map((s) => s.name).toList();
                      
                      debugPrint('🔧 Dropdown build: semesters count=${authService.semesters.length}');
                      debugPrint('🔧 Dropdown build: userInfo=${authService.userInfo != null}');
                      debugPrint('🔧 Dropdown build: semester names=$semesterNames');
                      debugPrint('🔧 Dropdown build: selected=${selectedSemester?.name}');
                      
                      return CupertinoDropdown(
                        value: selectedSemester?.name,
                        items: semesterNames.isNotEmpty ? semesterNames : [],
                        hintText: semesterNames.isEmpty ? 'Loading semesters...' : 'Select semester',
                        onChanged: semesterNames.isEmpty ? null : (semesterName) {
                          if (semesterName != null) {
                            // Find semester by name and select it
                            final semester = authService.semesters.firstWhere(
                              (s) => s.name == semesterName,
                            );
                            authService.selectSemester(semester.id).then((_) {
                              debugPrint('Selected semester: ${semester.name} (${semester.id})');
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
                
                // Student Dropdown (only for mentors with students)
                if (authService.permissions.canShowStudentSelection) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(_horizontalPadding, _horizontalPadding, _horizontalPadding, 8),
                    child: Text(
                      'User',
                      style: TextStyle(
                        color: themeService.textTertiaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 32, right: 80),
                    child: Consumer<AuthService>(
                      builder: (context, authService, child) {
                        final selectedStudent = authService.getSelectedStudent();
                        return CupertinoDropdown(
                          value: selectedStudent?.name, // No default to first student
                          items: authService.students.map((student) => student.name).toList(),
                          hintText: selectedStudent == null ? 'Select user' : 'Select user',
                          onChanged: (studentName) {
                            if (studentName != null) {
                              // Find student by name and select them
                              final student = authService.students.firstWhere(
                                (s) => s.name == studentName,
                              );
                              authService.selectStudent(student.id).then((_) {
                                debugPrint('Selected student: ${student.name} (${student.id})');
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
                
                const SizedBox(height: 8),
                // Navigation label
                Padding(
                  padding: const EdgeInsets.fromLTRB(_horizontalPadding, _horizontalPadding, _horizontalPadding, 8),
                  child: Text(
                    'Navigation',
                    style: TextStyle(
                      color: themeService.textTertiaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Settings with indent
                Padding(
                  padding: const EdgeInsets.only(left: _itemIndentPadding),
                  child: _buildDrawerItem(
                    context: context,
                    title: 'Settings',
                    isSelected: currentRoute == '/settings',
                    svgPath: 'assets/icons/ic_settings.svg',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      context.push('/settings');
                    },
                  ),
                ),
                // Logout Button with indent
                Padding(
                  padding: const EdgeInsets.only(left: _itemIndentPadding),
                  child: _buildLogoutItem(context, authService),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                  child: Divider(color: themeService.borderColor, height: 1),
                ),
                // Version Info (compact)
                const VersionEnvironmentWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required String title,
    required bool isSelected,
    IconData? icon,
    String? svgPath,
    String? route,
    VoidCallback? onTap,
  }) {
    assert(icon != null || svgPath != null, 'Either icon or svgPath must be provided');
    assert(!(icon != null && svgPath != null), 'Cannot provide both icon and svgPath');
    
    final themeService = context.watch<ThemeService>();
    final iconColor = isSelected ? ThemeService.accent : themeService.textSecondaryColor;
    
    Widget leadingWidget;
    if (icon != null) {
      leadingWidget = Icon(icon, color: iconColor);
    } else {
      leadingWidget = SvgPicture.asset(
        svgPath!,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      );
    }
    
    return ListTile(
      leading: leadingWidget,
      title: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? ThemeService.accent
              : themeService.textSecondaryColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: ThemeService.accent.withValues(alpha: 0.1),
      onTap: onTap ?? _defaultOnTap(context, route),
    );
  }

  VoidCallback? _defaultOnTap(BuildContext context, String? route) {
    return route != null
        ? () {
            Navigator.pop(context); // Close drawer
            context.go(route);
          }
        : null;
  }

  Widget _buildLogoutItem(BuildContext context, AuthService authService) {
    return ListTile(
      leading: const Icon(
        Icons.logout,
        color: AppColors.logoutColor,
      ),
      title: const Text(
        'Logout',
        style: TextStyle(
          color: AppColors.logoutColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => _handleLogout(context, authService),
    );
  }

  Future<void> _handleLogout(BuildContext context, AuthService authService) async {
    final shouldLogout = await _showLogoutConfirmationDialog(context);
    
    if (shouldLogout == true && context.mounted) {
      // Get StreamChatService if available
      StreamChatService? streamChatService;
      try {
        streamChatService = Provider.of<StreamChatService>(context, listen: false);
        // Set user offline before disconnecting
        await streamChatService.setUserOffline();
        // Disconnect Stream Chat on logout
        await streamChatService.disconnectUser();
      } catch (e) {
        // StreamChatService might not be available in all contexts
        debugPrint('🟡 [LOGOUT] StreamChatService not available: $e');
      }
      
      await authService.signOut(streamChatService: streamChatService);
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  Future<bool?> _showLogoutConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.logoutColor),
            ),
          ),
        ],
      ),
    );
  }
}
