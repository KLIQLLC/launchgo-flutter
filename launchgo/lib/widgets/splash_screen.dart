import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
                  // Logo with same dimensions as login screen
                  SvgPicture.asset(
                    'assets/images/launchgo_logo.svg',
                    height: 80,
                    width: 240,
                    fit: BoxFit.contain,
                    colorFilter: null,
                  ),
                  // Add spacing to match login screen layout
                  const SizedBox(height: 80),
                  // Invisible placeholder to match button height
                  const SizedBox(height: 54),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}