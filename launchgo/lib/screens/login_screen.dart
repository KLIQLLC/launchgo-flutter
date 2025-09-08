import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _handleSignIn() async {
    final authService = context.read<AuthService>();
    
    final success = await authService.signIn();
    
    if (mounted) {
      // Only navigate if both authentication and access token are available
      if (success && authService.isAuthenticated && authService.hasAccessToken) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${authService.currentUser?.displayName ?? authService.currentUser?.email}!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/schedule');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    final authService = context.read<AuthService>();
    await authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFFE3732), // Red color from your gradient
                  Color(0xFFFF894B), // Orange color from your gradient
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    SvgPicture.asset(
                      'assets/images/launchgo_logo.svg',
                      height: 80,
                      width: 240,
                      fit: BoxFit.contain,
                      colorFilter: null
                    ),
                    const SizedBox(height: 80),
                    
                    // Show Sign In button if:
                    // 1. User is not signed in with Google at all, OR
                    // 2. User is signed in with Google but doesn't have backend access token
                    if (authService.currentUser == null || !authService.hasAccessToken) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: authService.isSigningIn ? null : _handleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textPrimary,
                            foregroundColor: Colors.black87,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: AppColors.textGrey),
                            ),
                          ),
                          child: authService.isSigningIn
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.textGrey),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/icons/ic_google.svg',
                                      height: 24,
                                      width: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      // Show different text based on state
                                      authService.currentUser != null 
                                          ? 'Retry Authentication' 
                                          : 'Sign in with Google',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      
                      // Show sign out option if user is signed in with Google
                      // but backend authentication failed
                      if (authService.currentUser != null && !authService.hasAccessToken) ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _handleSignOut,
                          child: const Text(
                            'Sign in with different account',
                            style: TextStyle(
                              color: AppColors.textWhite70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      // This case should not happen anymore since we check hasAccessToken above
                      // Keeping for safety
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _handleSignOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: AppColors.textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  }
}