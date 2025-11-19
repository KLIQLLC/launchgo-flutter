import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ThemeService extends ChangeNotifier {
  // Re-export colors from AppColors for backward compatibility
  static const darkBackground = AppColors.darkBackground;
  static const darkCard = AppColors.darkCard;
  static const darkBorder = AppColors.darkBorder;
  static const accent = AppColors.accent;
  static const gradient1 = AppColors.gradient1;
  static const gradient2 = AppColors.gradient2;
  
  // All colors are now dark theme colors
  Color get backgroundColor => AppColors.darkBackground;
  Color get cardColor => AppColors.darkCard;
  Color get borderColor => AppColors.darkBorder;
  Color get textColor => AppColors.textPrimary;
  Color get textSecondaryColor => AppColors.textSecondaryTranslucent;
  Color get textTertiaryColor => AppColors.textTertiaryTranslucent;
  Color get iconColor => AppColors.textSecondaryTranslucent;
  
  // Input field specific colors
  Color get inputTextColor => AppColors.inputText;
  Color get inputPlaceholderColor => AppColors.inputPlaceholder;
  
  // Constructor - no need to load theme since it's always dark
  ThemeService();
  
  // ThemeData for MaterialApp - Always dark theme
  ThemeData get themeData => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    primaryColor: accent,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    dividerColor: borderColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}