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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Try to load SVG, fallback to text
              SvgPicture.asset(
                'assets/images/launchgo_logo.svg',
                height: 120,
                width: 300,
                fit: BoxFit.contain,
                colorFilter: null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}