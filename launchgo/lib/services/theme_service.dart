import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeService extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _themeKey = 'app_theme';
  
  bool _isDarkMode = true; // Default to dark mode
  
  bool get isDarkMode => _isDarkMode;
  
  // Color definitions
  static const darkBackground = Color(0xFF0F1318);
  static const darkCard = Color(0xFF1A1F2B);
  static const darkBorder = Color(0xFF2A303E);
  static const accent = Color(0xFF7B8CDE);
  static const gradient1 = Color(0xFFFE3732);
  static const gradient2 = Color(0xFFFF894B);
  
  // Light theme colors
  static const lightBackground = Colors.white;
  static const lightCard = Colors.white;
  static const lightBorder = Color(0xFFE0E0E0);
  static const lightText = Colors.black87;
  
  // Dynamic colors based on theme
  Color get backgroundColor => _isDarkMode ? darkBackground : lightBackground;
  Color get cardColor => _isDarkMode ? darkCard : lightCard;
  Color get borderColor => _isDarkMode ? darkBorder : lightBorder;
  Color get textColor => _isDarkMode ? Colors.white : lightText;
  Color get textSecondaryColor => _isDarkMode 
      ? Colors.white.withValues(alpha: 0.7) 
      : Colors.grey.shade600;
  Color get textTertiaryColor => _isDarkMode 
      ? Colors.white.withValues(alpha: 0.5) 
      : Colors.grey.shade500;
  Color get iconColor => _isDarkMode 
      ? Colors.white.withValues(alpha: 0.7) 
      : Colors.grey.shade700;
  
  ThemeService() {
    _loadTheme();
  }
  
  Future<void> _loadTheme() async {
    try {
      final themeValue = await _storage.read(key: _themeKey);
      if (themeValue != null) {
        _isDarkMode = themeValue == 'dark';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }
  
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    
    try {
      await _storage.write(
        key: _themeKey,
        value: _isDarkMode ? 'dark' : 'light',
      );
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }
  
  Future<void> setDarkMode(bool isDark) async {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      notifyListeners();
      
      try {
        await _storage.write(
          key: _themeKey,
          value: _isDarkMode ? 'dark' : 'light',
        );
      } catch (e) {
        debugPrint('Error saving theme: $e');
      }
    }
  }
  
  // ThemeData for MaterialApp
  ThemeData get themeData => ThemeData(
    brightness: _isDarkMode ? Brightness.dark : Brightness.light,
    primarySwatch: Colors.blue,
    primaryColor: accent,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    dividerColor: borderColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: _isDarkMode ? Brightness.dark : Brightness.light,
    ),
    useMaterial3: true,
  );
}