import 'package:flutter/material.dart';

/// Centralized color palette for the launchgo app
/// This class contains all color definitions used throughout the app
/// for consistency and maintainability
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ===== Core Theme Colors =====
  static const Color darkBackground = Color(0xFF0B1222);
  static const Color darkCard = Color(0xFF020817);
  static const Color darkBorder = Color(0xFF2A303E);
  static const Color accent = Color(0xFF7B8CDE);
  static const Color gradient1 = Color(0xFFFE3732);
  static const Color gradient2 = Color(0xFFFF894B);
  static const Color splashBackground = Color(0xFF0B131E);
  
  // ===== Text Colors =====
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF808080);
  static Color textSecondaryTranslucent = Colors.white.withValues(alpha: 0.7);
  static Color textTertiaryTranslucent = Colors.white.withValues(alpha: 0.5);
  static Color textWhite30 = Colors.white.withValues(alpha: 0.3);
  static const Color textWhite70 = Colors.white70;
  static const Color textGrey = Colors.grey;
  
  // ===== Input Field Colors =====
  static const Color inputText = Color(0xFFE6E8EA);
  static const Color inputPlaceholder = Color(0xFF93A2B7);
  
  // ===== Semantic Colors =====
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);
  
  // ===== Button Colors =====
  static const Color buttonPrimary = Colors.white;
  static const Color buttonDanger = error;
  static const Color buttonDangerText = Colors.white;
  static const Color buttonGrey = Color(0xFF616161); // grey.shade700
  
  // ===== Badge Colors =====
  static const Color badgeGrey = Color(0xFF37474F);
  static const Color badgeRed = error;
  
  // ===== Bottom Navigation Colors =====
  static const Color bottomNavBackground = darkCard;
  static const Color bottomNavSelected = accent;
  static Color bottomNavUnselected = Colors.white.withValues(alpha: 0.5);
  
  // ===== Special UI Colors =====
  static const Color logoutColor = Color(0xFF7F1E1D); // Dark red
  static const Color dividerColor = darkBorder;
  
  // ===== Grade Colors System =====
  // Each grade has a light background with dark text for accessibility
  
  // Grade A - Green theme
  static const Color gradeABackground = Color(0xFFDCFCE7);
  static const Color gradeAText = Color(0xFF166534);
  
  // Grade B - Blue theme  
  static const Color gradeBBackground = Color(0xFFDBE9FE);
  static const Color gradeBText = Color(0xFF1E40AF);
  
  // Grade C - Yellow theme
  static const Color gradeCBackground = Color(0xFFFEF3C7);
  static const Color gradeCText = Color(0xFF92400E);
  
  // Grade D - Orange theme
  static const Color gradeDBackground = Color(0xFFFFEDD7);
  static const Color gradeDText = Color(0xFF9A3412);
  
  // Grade F - Red theme
  static const Color gradeFBackground = Color(0xFFFEE2E2);
  static const Color gradeFText = Color(0xFF991B1B);
  
  // Grade W (Withdrawal) - Light grey theme
  static const Color gradeWBackground = Color(0xFFF3F4F6);
  static const Color gradeWText = Color(0xFF1F2937);
  
  // Grade IP (In Progress) - Light grey theme
  static const Color gradeIPBackground = Color(0xFFF3F4F6);
  static const Color gradeIPText = Color(0xFF374151);
  
  // Grade N/A or null
  static const Color gradeNABackground = Color(0xFFF3F4F6);
  static const Color gradeNAText = Color(0xFF6B7280);
  
  // ===== Status Colors (Assignments) =====
  
  // Pending - Blue
  static const Color statusPendingBackground = Color(0xFF2196F3);
  static const Color statusPendingText = Color(0xFF1976D2);
  
  // Completed - Green
  static const Color statusCompletedBackground = Color(0xFF4CAF50);
  static const Color statusCompletedText = Color(0xFF2E7D32);
  
  // Overdue - Red
  static const Color statusOverdueBackground = Color(0xFFF44336);
  static const Color statusOverdueText = Color(0xFFD32F2F);
  
  // ===== Document Tag Colors =====
  // Study Guide
  static const Color documentStudyGuideBackground = Color(0xFFF6F9FB);
  static const Color documentStudyGuideText = Color(0xFF0D1220);
  
  // Assignment
  static const Color documentAssignmentBackgroundDark = Color(0xFF1E293B);
  static const Color documentAssignmentTextDark = Color(0xFFFFFFFF);
  
  // Notes
  static const Color documentNotesBackgroundDark = Color(0xFF16A34A);
  static const Color documentNotesTextDark = Color(0xFFFFFFFF);
  
  // ===== Helper Methods =====
  
  /// Get grade background color based on grade string
  static Color getGradeBackground(String? grade) {
    if (grade == null || grade.isEmpty) return gradeNABackground;
    
    final upperGrade = grade.toUpperCase();
    if (upperGrade.startsWith('A')) return gradeABackground;
    if (upperGrade.startsWith('B')) return gradeBBackground;
    if (upperGrade.startsWith('C')) return gradeCBackground;
    if (upperGrade.startsWith('D')) return gradeDBackground;
    if (upperGrade == 'F') return gradeFBackground;
    if (upperGrade == 'W') return gradeWBackground;
    if (upperGrade == 'IP') return gradeIPBackground;
    
    return gradeNABackground;
  }
  
  /// Get grade text color based on grade string
  static Color getGradeTextColor(String? grade) {
    if (grade == null || grade.isEmpty) return gradeNAText;
    
    final upperGrade = grade.toUpperCase();
    if (upperGrade.startsWith('A')) return gradeAText;
    if (upperGrade.startsWith('B')) return gradeBText;
    if (upperGrade.startsWith('C')) return gradeCText;
    if (upperGrade.startsWith('D')) return gradeDText;
    if (upperGrade == 'F') return gradeFText;
    if (upperGrade == 'W') return gradeWText;
    if (upperGrade == 'IP') return gradeIPText;
    
    return gradeNAText;
  }
  
  /// Get status color for assignments
  static Color getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return statusCompletedText;
      case 'overdue':
        return statusOverdueText;
      case 'pending':
        return statusPendingText;
      default:
        return statusPendingText;
    }
  }
  
  /// Get status background color for assignments
  static Color getStatusBackgroundColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return statusCompletedBackground;
      case 'overdue':
        return statusOverdueBackground;
      case 'pending':
        return statusPendingBackground;
      default:
        return statusPendingBackground;
    }
  }
}