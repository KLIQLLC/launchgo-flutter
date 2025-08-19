import 'package:flutter/material.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:provider/provider.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    
    return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildCourseCard(
            context,
            'Math 101',
            'Introduction to Calculus',
            'Prof. Smith',
            Colors.blue,
          ),
          _buildCourseCard(
            context,
            'History 202',
            'World History',
            'Dr. Johnson',
            Colors.green,
          ),
          _buildCourseCard(
            context,
            'English 303',
            'Advanced Writing',
            'Prof. Williams',
            Colors.orange,
          ),
        ],
      );
  }

  Widget _buildCourseCard(BuildContext context, String code, String title, String instructor, Color color) {
    final themeService = context.watch<ThemeService>();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: themeService.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: themeService.borderColor,
          width: 1,
        ),
        boxShadow: !themeService.isDarkMode ? [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.book,
            color: color,
          ),
        ),
        title: Text(
          code,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: themeService.textColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: themeService.textColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              instructor,
              style: TextStyle(
                color: themeService.textSecondaryColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios, 
          size: 16, 
          color: themeService.textTertiaryColor,
        ),
      ),
    );
  }
}