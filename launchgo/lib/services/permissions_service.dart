import '../models/user_model.dart';

/// Centralized service for managing role-based permissions and UI visibility
/// This service defines all role-based logic in one place for consistency
class PermissionsService {
  final UserModel? _userInfo;
  
  const PermissionsService(this._userInfo);

  // Role getters
  bool get isStudent => _userInfo?.isStudent ?? false;
  bool get isMentor => _userInfo?.isMentor ?? false;
  bool get isCaseManager => _userInfo?.isCaseManager ?? false;

  // UI Visibility Permissions
  
  /// Should show student selection dropdown in app drawer
  /// Only mentors with students should see this
  bool get canShowStudentSelection => isMentor && (_userInfo?.students.isNotEmpty ?? false);
  
  /// Should show Recaps tab in bottom navigation
  /// Hidden for students, visible for mentors and case managers
  bool get canShowRecapsTab => !isStudent;
  
  /// Can access Recaps screen directly via URL
  /// Same logic as tab visibility
  bool get canAccessRecaps => !isStudent;

  // Document Operation Permissions
  
  /// Can create documents - disabled for students
  bool get canCreateDocuments => !isStudent;
  
  /// Can edit documents - disabled for students
  bool get canEditDocuments => !isStudent;
  
  /// Can delete documents - disabled for students
  bool get canDeleteDocuments => !isStudent;
  
  /// Can view analytics/reports
  bool get canViewAnalytics => isMentor || isCaseManager;
  
  /// Can manage students (assign, remove, etc.)
  bool get canManageStudents => isMentor || isCaseManager;
  
  /// Can access admin features
  bool get canAccessAdmin => isCaseManager;

  // Event Management Permissions
  
  /// Can create events - disabled for students
  bool get canCreateEvents => !isStudent;
  
  /// Can edit events - disabled for students
  bool get canEditEvents => !isStudent;
  
  /// Can delete events - disabled for students
  bool get canDeleteEvents => !isStudent;

  // Navigation Permissions
  
  /// Get list of available navigation routes for this role
  List<String> get availableRoutes {
    List<String> routes = ['/schedule', '/courses', '/documents', '/goals'];
    
    if (canShowRecapsTab) {
      routes.insert(3, '/recaps'); // Insert before goals
    }
    
    return routes;
  }
  
  /// Get navigation index for a given route, accounting for role-based visibility
  int? getNavigationIndex(String route) {
    final routes = availableRoutes;
    final index = routes.indexOf(route);
    return index >= 0 ? index : null;
  }
  
  /// Get route for a given navigation index, accounting for role-based visibility
  String? getRouteForIndex(int index) {
    final routes = availableRoutes;
    return index < routes.length ? routes[index] : null;
  }

  // Helper Methods
  
  /// Should redirect from a route based on permissions
  String? getRedirectRoute(String currentRoute) {
    if (currentRoute == '/recaps' && !canAccessRecaps) {
      return '/schedule'; // Redirect students away from recaps
    }
    if (currentRoute == '/new-document' && !canCreateDocuments) {
      return '/documents'; // Redirect students away from document creation
    }
    if (currentRoute.startsWith('/edit-document/') && !canEditDocuments) {
      return '/documents'; // Redirect students away from document editing
    }
    return null; // No redirect needed
  }
  
  /// Get display name for current user role
  String get roleDisplayName {
    if (isStudent) return 'User';
    if (isMentor) return 'Mentor';
    if (isCaseManager) return 'Case Manager';
    return 'Unknown';
  }
}