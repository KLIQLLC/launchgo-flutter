import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  
  const StatusBadge._({
    required this.text,
    required this.color,
  });
  
  factory StatusBadge.fromStatus(String status) {
    // Capitalize first letter for display
    final displayText = status.substring(0, 1).toUpperCase() + status.substring(1).toLowerCase();
    
    return StatusBadge._(
      text: displayText,
      color: AppColors.getStatusColor(status),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}