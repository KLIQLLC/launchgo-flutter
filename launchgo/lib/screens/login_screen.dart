import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isAgeConsentChecked = false;
  bool _isPrivacyPolicyChecked = false;

  bool get _canSignIn => _isAgeConsentChecked && _isPrivacyPolicyChecked;

  Future<void> _handleSignIn() async {
    // Check if both checkboxes are checked
    if (!_canSignIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to both terms before signing in'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
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

  Future<void> _launchPrivacyPolicy() async {
    final uri = Uri.parse('https://app.termly.io/policy-viewer/policy.html?policyUUID=f251ca64-f15f-4f59-aefd-be8ffe01c6b6');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open privacy policy'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              color: AppColors.splashBackground,
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
                      // Age consent checkbox
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 320,
                        ),
                        child: CheckboxListTile(
                          value: _isAgeConsentChecked,
                          onChanged: (value) {
                            setState(() {
                              _isAgeConsentChecked = value ?? false;
                            });
                          },
                          title: const Text(
                            'I am over 13 years old and/or have my parent or guardians permission to use this application.',
                            style: TextStyle(
                              color: AppColors.textWhite70,
                              fontSize: 14,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Privacy policy checkbox
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 320,
                        ),
                        child: CheckboxListTile(
                          value: _isPrivacyPolicyChecked,
                          onChanged: (value) {
                            setState(() {
                              _isPrivacyPolicyChecked = value ?? false;
                            });
                          },
                          title: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: AppColors.textWhite70,
                                fontSize: 14,
                              ),
                              children: [
                                const TextSpan(text: 'I have read and agree to the '),
                                TextSpan(
                                  text: 'privacy policy and terms of use',
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = _launchPrivacyPolicy,
                                ),
                              ],
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 320, // Maximum width for iPad
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: authService.isSigningIn || !_canSignIn ? null : _handleSignIn,
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
                                        colorFilter: !_canSignIn 
                                            ? const ColorFilter.mode(
                                                AppColors.textGrey, 
                                                BlendMode.srcIn,
                                              )
                                            : null,
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