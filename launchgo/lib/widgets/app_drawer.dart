import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return Drawer(
      backgroundColor: const Color(0xFF0F1318),
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
                colors: [
                  Color(0xFFFE3732),
                  Color(0xFFFF894B),
                ],
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
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // User info
                    Text(
                      authService.currentUser?.displayName ?? 'Student',
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
                _buildDrawerItem(
                  context: context,
                  icon: Icons.calendar_month,
                  title: 'Schedule',
                  route: '/schedule',
                  isSelected: currentRoute == '/schedule',
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.school,
                  title: 'Courses',
                  route: '/courses',
                  isSelected: currentRoute == '/courses',
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.folder,
                  title: 'Documents',
                  route: '/documents',
                  isSelected: currentRoute == '/documents',
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.summarize,
                  title: 'Recaps',
                  route: '/recaps',
                  isSelected: currentRoute == '/recaps',
                ),
                const Divider(),
                _buildDrawerItem(
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
                const Divider(),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  route: null,
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Implement help & support
                  },
                ),
                // Version Info (compact)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'v$_version ($_buildNumber)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Logout Button
          Container(
            padding: const EdgeInsets.all(20),
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
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF7B8CDE) : Colors.white.withValues(alpha: 0.7),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF7B8CDE) : Colors.white.withValues(alpha: 0.7),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFF7B8CDE).withValues(alpha: 0.1),
      onTap: onTap ?? (route != null ? () {
        Navigator.pop(context); // Close drawer
        context.go(route);
      } : null),
    );
  }
}