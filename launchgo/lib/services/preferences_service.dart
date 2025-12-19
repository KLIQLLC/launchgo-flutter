import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';

/// Service for managing user preferences using UserDefaults (iOS) / SharedPreferences (Android)
/// This is for non-sensitive user preferences like selected student/semester
class PreferencesService {
  static late SharedPreferences _prefs;
  static bool _initialized = false;
  
  /// Initialize the preferences service
  static Future<void> initialize() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }
  
  /// Get environment-specific key
  static String _getEnvironmentKey(String baseKey) {
    final env = EnvironmentConfig.isStage ? 'stage' : 'prod';
    return '${baseKey}_$env';
  }
  
  // Keys for user preferences (environment-specific)
  static String get _selectedStudentKey => _getEnvironmentKey('selected_student_id');
  static String get _selectedSemesterKey => _getEnvironmentKey('selected_semester_id');
  
  // Selected Student Methods
  
  /// Save selected student ID
  static Future<bool> saveSelectedStudentId(String? studentId) async {
    if (studentId == null) {
      return await _prefs.remove(_selectedStudentKey);
    }
    return await _prefs.setString(_selectedStudentKey, studentId);
  }
  
  /// Get selected student ID
  static String? getSelectedStudentId() {
    if (!_initialized) return null;
    return _prefs.getString(_selectedStudentKey);
  }
  
  /// Clear selected student ID
  static Future<bool> clearSelectedStudentId() async {
    return await _prefs.remove(_selectedStudentKey);
  }
  
  // Selected Semester Methods
  
  /// Save selected semester ID
  static Future<bool> saveSelectedSemesterId(String? semesterId) async {
    if (semesterId == null) {
      return await _prefs.remove(_selectedSemesterKey);
    }
    return await _prefs.setString(_selectedSemesterKey, semesterId);
  }
  
  /// Get selected semester ID
  static String? getSelectedSemesterId() {
    if (!_initialized) return null;
    return _prefs.getString(_selectedSemesterKey);
  }
  
  /// Clear selected semester ID
  static Future<bool> clearSelectedSemesterId() async {
    return await _prefs.remove(_selectedSemesterKey);
  }
  
  // Utility Methods
  
  /// Clear all user preferences for current environment
  static Future<void> clearAllPreferences() async {
    await clearSelectedStudentId();
    await clearSelectedSemesterId();
  }
  
  /// Clear all preferences for all environments
  static Future<void> clearAllEnvironmentPreferences() async {
    // Clear stage preferences
    await _prefs.remove('selected_student_id_stage');
    await _prefs.remove('selected_semester_id_stage');
    
    // Clear prod preferences  
    await _prefs.remove('selected_student_id_prod');
    await _prefs.remove('selected_semester_id_prod');
    
    // Clear legacy non-environment-specific preferences
    await _prefs.remove('selected_student_id');
    await _prefs.remove('selected_semester_id');
  }
  
  // Stream Video credentials for native Android access
  // These are stored without environment suffix so native code can access them
  static const String _streamVideoTokenKey = 'stream_video_token';
  static const String _streamVideoApiKeyKey = 'stream_video_api_key';
  static const String _streamVideoUserIdKey = 'stream_video_user_id';

  /// Save Stream Video credentials for native Android access
  /// This is needed for background call rejection
  static Future<void> saveStreamVideoCredentials({
    required String token,
    required String apiKey,
    required String userId,
  }) async {
    await _prefs.setString(_streamVideoTokenKey, token);
    await _prefs.setString(_streamVideoApiKeyKey, apiKey);
    await _prefs.setString(_streamVideoUserIdKey, userId);
  }

  /// Clear Stream Video credentials
  static Future<void> clearStreamVideoCredentials() async {
    await _prefs.remove(_streamVideoTokenKey);
    await _prefs.remove(_streamVideoApiKeyKey);
    await _prefs.remove(_streamVideoUserIdKey);
  }

  /// Migrate old preferences to environment-specific storage
  static Future<void> migrateOldPreferences() async {
    // Check for legacy preferences without environment suffix
    final oldStudentId = _prefs.getString('selected_student_id');
    final oldSemesterId = _prefs.getString('selected_semester_id');
    
    if (oldStudentId != null || oldSemesterId != null) {
      // Migrate to current environment
      if (oldStudentId != null) {
        await saveSelectedStudentId(oldStudentId);
      }
      if (oldSemesterId != null) {
        await saveSelectedSemesterId(oldSemesterId);
      }
      
      // Clear old preferences
      await _prefs.remove('selected_student_id');
      await _prefs.remove('selected_semester_id');
    }
  }
}