import 'package:flutter/material.dart';
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
              Icon(
                Icons.calendar_month,
                size: 80,
                color: ThemeService.accent,
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