import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Service to handle pending navigations from push notifications
/// This ensures navigation happens after the app is fully initialized
class PendingNavigationService extends ChangeNotifier {
  static PendingNavigationService? _instance;
  static PendingNavigationService get instance => 
      _instance ??= PendingNavigationService._();
  
  /// Reset the singleton instance (for hot reload support)
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }
  
  PendingNavigationService._();
  
  String? _pendingRoute;
  Map<String, dynamic>? _pendingExtra;
  GoRouter? _router;
  bool _isProcessing = false;
  
  /// Set the router instance
  void setRouter(GoRouter router) {
    _router = router;
    debugPrint('📍 PendingNavigationService: Router set');
    
    // Process any pending navigation immediately
    if (_pendingRoute != null) {
      debugPrint('📍 Found pending navigation, processing immediately');
      processPendingNavigation();
    }
  }
  
  /// Log to file for debugging
  Future<void> _logToFile(String message) async {
    try {
      final file = File('debug_logs.txt');
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString('[$timestamp] $message\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }
  
  /// Store a pending navigation
  void setPendingNavigation(String route, {Map<String, dynamic>? extra}) {
    final logMessage = '''
============================================
Storing pending navigation to: $route
Extra data: $extra
============================================''';
    
    debugPrint('📍 $logMessage');
    _logToFile('PENDING_NAVIGATION: $logMessage');
    
    _pendingRoute = route;
    _pendingExtra = extra;
    notifyListeners();
    
    // If router is already available, process immediately
    if (_router != null && !_isProcessing) {
      debugPrint('📍 Router available, processing navigation immediately');
      processPendingNavigation();
    }
  }
  
  /// Process any pending navigation
  void processPendingNavigation() {
    if (_isProcessing) {
      debugPrint('📍 Already processing navigation, skipping');
      return;
    }
    
    if (_pendingRoute == null) {
      debugPrint('📍 No pending navigation to process');
      return;
    }
    
    if (_router == null) {
      debugPrint('📍 Router not available yet, will retry later');
      Future.delayed(const Duration(seconds: 1), () {
        processPendingNavigation();
      });
      return;
    }
    
    _isProcessing = true;
    final route = _pendingRoute!;
    final extra = _pendingExtra;
    
    debugPrint('📍 ============================================');
    debugPrint('📍 Processing pending navigation');
    debugPrint('📍 Target route: $route');
    debugPrint('📍 Extra data: $extra');
    debugPrint('📍 Current location: ${_router?.routerDelegate.currentConfiguration.uri}');
    
    // Clear pending navigation first
    _pendingRoute = null;
    _pendingExtra = null;
    
    // Execute navigation synchronously without delays
    debugPrint('📍 Executing navigation synchronously');
    try {
      debugPrint('📍 Executing navigation to: $route');
      
      // Use router.go directly for immediate navigation
      if (extra != null && extra.isNotEmpty) {
        _router!.go(route, extra: extra);
      } else {
        _router!.go(route);
      }
      
      debugPrint('📍 Navigation executed successfully');
      debugPrint('📍 New location: ${_router?.routerDelegate.currentConfiguration.uri}');
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      debugPrint('❌ Attempting fallback to /schedule');
      
      // Try fallback
      try {
        _router!.go('/schedule');
      } catch (e2) {
        debugPrint('❌ Fallback navigation also failed: $e2');
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
    debugPrint('📍 ============================================');
  }
  
  /// Clear any pending navigation
  void clearPendingNavigation() {
    debugPrint('📍 Clearing pending navigation');
    _pendingRoute = null;
    _pendingExtra = null;
    _isProcessing = false;
    notifyListeners();
  }
  
  /// Check if there's a pending navigation
  bool get hasPendingNavigation => _pendingRoute != null;
  
  /// Get pending route
  String? get pendingRoute => _pendingRoute;
}