import '../models/user_model.dart';
import '../models/user_permission_type.dart';

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

  /// Mentor-only shell tab (student event permission toggles for selected student).
  bool get canShowMentorSettingsTab =>
      isMentor && (_userInfo?.students.isNotEmpty ?? false);

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

  /// Can create events — mentors/CMS always; students only if mentor enabled [UserPermissionType.eventCreate].
  bool get canCreateEvents {
    if (!isStudent) return true;
    return _userInfo?.hasPermission(UserPermissionType.eventCreate) ?? false;
  }

  /// Can edit calendar events — mentors/CMS always; students per [UserPermissionType.eventUpdate].
  bool get canEditEvents {
    if (!isStudent) return true;
    return _userInfo?.hasPermission(UserPermissionType.eventUpdate) ?? false;
  }

  /// Can delete calendar events — mentors/CMS always; students per [UserPermissionType.eventDelete].
  bool get canDeleteEvents {
    if (!isStudent) return true;
    return _userInfo?.hasPermission(UserPermissionType.eventDelete) ?? false;
  }

  // Navigation Permissions
  
  /// Get list of available navigation routes for this role
  List<String> get availableRoutes {
    List<String> routes = ['/schedule', '/courses', '/documents'];

    if (canShowRecapsTab) {
      routes.add('/recaps');
    }

    if (canShowMentorSettingsTab) {
      routes.add('/settings');
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
    if (currentRoute == '/settings' && !canShowMentorSettingsTab) {
      return '/schedule';
    }
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
    if (isStudent) return 'Client';
    if (isMentor) return 'Mentor';
    if (isCaseManager) return 'Case Manager';
    return 'Unknown';
  }
}