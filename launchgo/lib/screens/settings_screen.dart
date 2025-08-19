import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
                        authService.currentUser?.displayName ?? 'Student',
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
          
          Divider(color: themeService.borderColor),
          
          // Theme Toggle
          ListTile(
            leading: Icon(
              themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: themeService.iconColor,
            ),
            title: Text(
              'Dark Theme',
              style: TextStyle(color: themeService.textColor),
            ),
            trailing: Switch(
              value: themeService.isDarkMode,
              onChanged: (value) => themeService.setDarkMode(value),
              activeColor: ThemeService.accent,
            ),
          ),
          
          Divider(color: themeService.borderColor),
          
          // App Version
          ListTile(
            leading: Icon(Icons.info_outline, color: themeService.iconColor),
            title: Text('Version', style: TextStyle(color: themeService.textColor)),
            subtitle: Text(
              '$_version ($_buildNumber)',
              style: TextStyle(color: themeService.textSecondaryColor),
            ),
          ),
          
          Divider(color: themeService.borderColor),
          
          // Logout Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: () async {
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
                
                if (shouldLogout == true) {
                  await authService.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}