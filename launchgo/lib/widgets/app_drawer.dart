import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:launchgo/widgets/cupertino_dropdown.dart';
import 'package:launchgo/widgets/version_environment_widget.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  void initState() {
    super.initState();
    // Load semesters when drawer opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      if (authService.semesters.isEmpty) {
        authService.loadSemesters();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final themeService = context.watch<ThemeService>();
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return Drawer(
      backgroundColor: themeService.backgroundColor,
      child: Column(
        children: [
          // Drawer Header with gradient
          Container(
            height: 210,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFE3732), Color(0xFFFF894B)],
              ),
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
                      height: 50,
                      width: 120,
                      fit: BoxFit.contain,
                      colorFilter: null
                    ),
                    const SizedBox(height: 12),
                    // User info
                    Text(
                      authService.currentUser?.displayName ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      authService.currentUser?.email ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Student',
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
                          value: selectedStudent?.name ?? authService.students.first.name,
                          items: authService.students.map((student) => student.name).toList(),
                          hintText: 'Select student',
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                  padding: const EdgeInsets.only(left: 16),
                  child: _buildDrawerItem(
                    context: context,
                    icon: Icons.settings,
                    title: 'Settings',
                    route: null,
                    isSelected: currentRoute == '/settings',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      context.push('/settings');
                    },
                  ),
                ),
                // Logout Button with indent
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: Color(0xFFFF6B35), // Warm orange-red
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Color(0xFFFF6B35), // Warm orange-red
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      // Show confirmation dialog
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text(
                            'Are you sure you want to logout?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'Logout',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (shouldLogout == true && context.mounted) {
                        await authService.signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      }
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
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
    required IconData icon,
    required String title,
    required String? route,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    final themeService = context.watch<ThemeService>();
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? ThemeService.accent
            : themeService.textSecondaryColor,
      ),
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
      onTap:
          onTap ??
          (route != null
              ? () {
                  Navigator.pop(context); // Close drawer
                  context.go(route);
                }
              : null),
    );
  }
}
