import 'package:flutter/material.dart';

/// Centralized color palette for the launchgo app
/// This class contains all color definitions used throughout the app
/// for consistency and maintainability
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ===== Primary Brand Colors =====
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFFBBDEFB);
  
  // ===== Neutral Colors =====
  static const Color backgroundDark = Color(0xFF1A1B1E);
  static const Color cardDark = Color(0xFF2D2E33);
  static const Color borderDark = Color(0xFF3A3B40);
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF808080);
  
  // ===== Grade Colors System =====
  // Each grade has a light background with dark text for accessibility
  
  // Grade A - Green theme
  static const Color gradeABackground = Color(0xFFDCFCE7);
  static const Color gradeAText = Color(0xFF166534);
  
  // Grade B - Blue theme  
  static const Color gradeBBackground = Color(0xFFDBE9FE);
  static const Color gradeBText = Color(0xFF1E40AF); // Darker blue text
  
  // Grade C - Yellow theme
  static const Color gradeCBackground = Color(0xFFFEF3C7);
  static const Color gradeCText = Color(0xFF92400E); // Darker brown/amber text
  
  // Grade D - Orange theme
  static const Color gradeDBackground = Color(0xFFFFEDD7); // sRGB(255, 237, 215) - light peach background
  static const Color gradeDText = Color(0xFF9A3412); // Darker orange/rust text
  
  // Grade F - Red theme
  static const Color gradeFBackground = Color(0xFFFEE2E2); // Light pink/red background
  static const Color gradeFText = Color(0xFF991B1B); // Darker red text
  
  // Grade W (Withdrawal) - Light grey theme
  static const Color gradeWBackground = Color(0xFFF3F4F6); // sRGB(243, 244, 246) - light grey background
  static const Color gradeWText = Color(0xFF1F2937); // Darker grey/almost black text
  
  // Grade IP (In Progress) - Light grey theme
  static const Color gradeIPBackground = Color(0xFFF3F4F6); // Very light grey/almost white background
  static const Color gradeIPText = Color(0xFF374151); // Dark grey text
  
  // Grade N/A or null
  static const Color gradeNABackground = Color(0xFFF3F4F6);
  static const Color gradeNAText = Color(0xFF6B7280);
  
  // ===== Status Colors (Assignments) =====
  
  // Pending - Blue
  static const Color statusPendingBackground = Color(0xFF2196F3);
  static const Color statusPendingText = Color(0xFF1976D2);
  static const Color statusPendingBorder = Color(0xFF2196F3);
  
  // Completed - Green
  static const Color statusCompletedBackground = Color(0xFF4CAF50);
  static const Color statusCompletedText = Color(0xFF2E7D32);
  static const Color statusCompletedBorder = Color(0xFF4CAF50);
  
  // Overdue - Red
  static const Color statusOverdueBackground = Color(0xFFF44336);
  static const Color statusOverdueText = Color(0xFFD32F2F);
  static const Color statusOverdueBorder = Color(0xFFF44336);
  
  // ===== Semantic Colors =====
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // ===== Badge Colors =====
  static const Color badgeGrey = Color(0xFF37474F);
  static const Color badgeLightGrey = Color(0xFF9E9E9E);
  
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
  
  // ===== Button Colors =====
  static const Color buttonPrimary = primaryBlue;
  static const Color buttonSecondary = Color(0xFF37474F);
  static const Color buttonDanger = error;
  static const Color buttonDisabled = Color(0xFF9E9E9E);
  
  // ===== Special UI Elements =====
  static const Color fabBackground = primaryBlue;
  static const Color fabIcon = Colors.white;
  static const Color accent = Color(0xFF00C853);
  
  // ===== Shadow Colors =====
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x33000000);
  static const Color shadowDark = Color(0x66000000);
  
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
  
  /// Get semantic color based on type
  static Color getSemanticColor(SemanticColorType type) {
    switch (type) {
      case SemanticColorType.success:
        return success;
      case SemanticColorType.warning:
        return warning;
      case SemanticColorType.error:
        return error;
      case SemanticColorType.info:
        return info;
    }
  }
}

/// Enum for semantic color types
enum SemanticColorType {
  success,
  warning,
  error,
  info,
}