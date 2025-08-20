import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:provider/provider.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    
    return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/ic_schedule.svg',
                width: 80,
                height: 80,
                colorFilter: const ColorFilter.mode(
                  ThemeService.accent,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Your Schedule',
                style: TextStyle(
                  color: themeService.textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'View and manage your learning schedule',
                style: TextStyle(
                  fontSize: 16, 
                  color: themeService.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      );
  }
}