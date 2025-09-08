import 'package:flutter/material.dart';

class ThemeService extends ChangeNotifier {
  // Always use dark mode
  static const bool _isDarkMode = true;
  
  bool get isDarkMode => _isDarkMode;
  
  // Color definitions - Dark theme only
  static const darkBackground = Color(0xFF0F1318);
  static const darkCard = Color(0xFF1A1F2B);
  static const darkBorder = Color(0xFF2A303E);
  static const accent = Color(0xFF7B8CDE);
  static const gradient1 = Color(0xFFFE3732);
  static const gradient2 = Color(0xFFFF894B);
  
  // All colors are now dark theme colors
  Color get backgroundColor => darkBackground;
  Color get cardColor => darkCard;
  Color get borderColor => darkBorder;
  Color get textColor => Colors.white;
  Color get textSecondaryColor => Colors.white.withValues(alpha: 0.7);
  Color get textTertiaryColor => Colors.white.withValues(alpha: 0.5);
  Color get iconColor => Colors.white.withValues(alpha: 0.7);
  
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