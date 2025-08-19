import 'package:flutter/material.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:provider/provider.dart';

class RecapsScreen extends StatelessWidget {
  const RecapsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    
    return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Recent Messages',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: themeService.textColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildMessageCard(
            context,
            'Dr. Harper',
            'Project update',
            'The deadline for the final project has been...',
            '2 hours ago',
            true,
          ),
          _buildMessageCard(
            context,
            'Owen',
            'Study group meeting',
            'Hey! Are we still meeting tomorrow at 3PM?',
            '5 hours ago',
            false,
          ),
          _buildMessageCard(
            context,
            'Prof. Smith',
            'Assignment feedback',
            'Great work on your recent submission...',
            'Yesterday',
            true,
          ),
          const SizedBox(height: 24),
          Text(
            'Weekly Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: themeService.textColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(
            context,
            'Completed Tasks',
            '12 assignments submitted',
            Icons.check_circle,
            Colors.green,
          ),
          _buildSummaryCard(
            context,
            'Upcoming Deadlines',
            '3 assignments due this week',
            Icons.schedule,
            Colors.orange,
          ),
        ],
      );
  }

  Widget _buildMessageCard(BuildContext context, String sender, String subject, String preview, String time, bool isMentor) {
    final themeService = context.watch<ThemeService>();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        leading: CircleAvatar(
          backgroundColor: isMentor 
              ? ThemeService.accent.withValues(alpha: 0.2) 
              : themeService.borderColor,
          child: Icon(
            Icons.person,
            color: isMentor 
                ? ThemeService.accent 
                : themeService.iconColor,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              sender,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: themeService.textColor,
              ),
            ),
            Text(
              time,
              style: TextStyle(
                color: themeService.textTertiaryColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subject,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: themeService.textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              preview,
              style: TextStyle(
                color: themeService.textSecondaryColor,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String subtitle, IconData icon, Color color) {
    final themeService = context.watch<ThemeService>();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeService.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: themeService.isDarkMode 
              ? color.withValues(alpha: 0.3)
              : color.withValues(alpha: 0.2),
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
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: themeService.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: themeService.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}