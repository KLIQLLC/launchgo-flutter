import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../api/api_service.dart';
import '../api/dio_client_enhanced.dart';
import 'auth_service.dart';

/// Service wrapper using Retrofit with Dio interceptors
class ApiServiceRetrofit {
  late final ApiService _retrofit;
  final AuthService _authService;
  
  ApiServiceRetrofit({required AuthService authService}) : _authService = authService {
    final dioClient = DioClientEnhanced(authService: _authService);
    _retrofit = ApiService(dioClient.dio);
  }
  
  /// Get the effective user ID (for mentors viewing students)
  String? _getEffectiveUserId() {
    if (_authService.userInfo?.isMentor == true && _authService.selectedStudentId != null) {
      debugPrint('📝 Using selected student ID: ${_authService.selectedStudentId}');
      return _authService.selectedStudentId;
    }
    final userId = _authService.userInfo?.id;
    debugPrint('📝 Using current user ID: $userId');
    return userId;
  }
  
  /// Parse response data that might be a JSON string
  dynamic _parseJsonResponse(dynamic data) {
    if (data is String) {
      try {
        return json.decode(data);
      } catch (e) {
        debugPrint('❌ Failed to parse response as JSON: $e');
        return null;
      }
    }
    return data;
  }
  
  // User endpoints
  
  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final response = await _retrofit.getUserInfo();
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      return parsedData is Map<String, dynamic> ? parsedData : null;
    } catch (e) {
      debugPrint('Failed to get user info: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>?> registerFCMToken(String token) async {
    try {
      debugPrint('📱 Registering FCM token with backend...');
      final response = await _retrofit.registerFCMToken({'token': token});
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      debugPrint('✅ FCM token registered successfully');
      return parsedData is Map<String, dynamic> ? parsedData : null;
    } catch (e) {
      debugPrint('❌ Failed to register FCM token: $e');
      rethrow;
    }
  }
  
  Future<void> deleteFCMToken(String token) async {
    try {
      debugPrint('🗑️ Deleting FCM token from backend...');
      await _retrofit.deleteFCMToken(token);
      debugPrint('✅ FCM token deleted successfully');
    } catch (e) {
      debugPrint('❌ Failed to delete FCM token: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>?> updateStudentInfo(String studentId, Map<String, dynamic> studentData) async {
    try {
      debugPrint('📝 Updating student info for: $studentId');
      final response = await _retrofit.updateStudentInfo(studentId, studentData);
      final parsedData = _parseJsonResponse(response.data);
      debugPrint('✅ Student info updated successfully');
      return parsedData is Map<String, dynamic> ? parsedData : null;
    } catch (e) {
      debugPrint('❌ Failed to update student info: $e');
      rethrow;
    }
  }
  
  // Semester endpoints
  
  Future<List<Map<String, dynamic>>> getSemesters() async {
    try {
      debugPrint('🔄 Retrofit: Getting semesters...');
      final response = await _retrofit.getSemesters();
      final data = response.data;
      debugPrint('📊 Response status: ${response.response.statusCode}');
      debugPrint('📊 Raw response data type: ${data.runtimeType}');
      
      final parsedData = _parseJsonResponse(data);
      if (parsedData is List) {
        final semesterList = List<Map<String, dynamic>>.from(parsedData);
        debugPrint('✅ Successfully parsed ${semesterList.length} semesters');
        return semesterList;
      }
      
      debugPrint('❌ No valid semester data found - data: $data');
      return [];
    } catch (e) {
      debugPrint('❌ Failed to get semesters: $e');
      return [];
    }
  }
  
  // Deadlines endpoints
  
  Future<List<Map<String, dynamic>>> getDeadlines({
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    try {
      // Ensure user info is loaded
      if (_authService.userInfo == null) {
        debugPrint('⚠️ User info not loaded yet, loading now...');
        await _authService.loadUserInfo();
      }
      
      final userId = _getEffectiveUserId();
      if (userId == null) {
        debugPrint('❌ Cannot get deadlines: User ID is null');
        return [];
      }
      
      // Format dates as required by API (YYYY-MM-DD HH:MM:SS)
      final startAtStr = _formatDateForDeadlines(startAt);
      final endAtStr = _formatDateForDeadlines(endAt);
      
      debugPrint('🔄 Getting deadlines for user $userId from $startAtStr to $endAtStr');
      final response = await _retrofit.getDeadlines(userId, startAtStr, endAtStr);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      if (parsedData == null) {
        debugPrint('❌ No valid deadline data found');
        return [];
      }
      
      debugPrint('✅ Successfully fetched deadlines');
      if (parsedData is List) {
        return List<Map<String, dynamic>>.from(parsedData);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Failed to get deadlines: $e');
      return [];
    }
  }
  
  // Document endpoints
  
  Future<List<Map<String, dynamic>>> getDocuments() async {
    try {
      // Ensure user info is loaded
      if (_authService.userInfo == null) {
        debugPrint('⚠️ User info not loaded yet, loading now...');
        await _authService.loadUserInfo();
      }
      
      final userId = _getEffectiveUserId();
      if (userId == null) {
        debugPrint('❌ Cannot get documents: User ID is null');
        return [];
      }
      
      // Ensure semester is selected
      if (_authService.selectedSemesterId == null) {
        debugPrint('⚠️ No semester selected, loading semesters...');
        await _authService.loadSemesters();
      }
      
      final semesterId = _authService.selectedSemesterId;
      if (semesterId == null) {
        debugPrint('❌ Cannot get documents: No semester selected');
        return [];
      }
      
      debugPrint('📚 Getting documents for user: $userId, semester: $semesterId');
      final response = await _retrofit.getDocuments(userId, semesterId);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      if (parsedData is List) {
        return List<Map<String, dynamic>>.from(parsedData);
      }
      
      return [];
    } catch (e) {
      debugPrint('Failed to get documents: $e');
      rethrow;
    }
  }
  
  // Course endpoints
  
  Future<List<Map<String, dynamic>>> getCourses() async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        debugPrint('❌ Cannot get courses: User ID is null');
        return [];
      }
      
      final semesterId = _authService.selectedSemesterId;
      if (semesterId == null) {
        debugPrint('❌ Cannot get courses: No semester selected');
        return [];
      }
      
      debugPrint('📚 Getting courses for user: $userId, semester: $semesterId');
      final response = await _retrofit.getCourses(userId, semesterId);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      if (parsedData is List) {
        return List<Map<String, dynamic>>.from(parsedData);
      }
      
      return [];
    } catch (e) {
      debugPrint('Failed to get courses: $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>?> getCourse(String courseId) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        debugPrint('User ID is null, cannot get course');
        return null;
      }
      
      final response = await _retrofit.getCourse(userId, courseId);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      return parsedData is Map<String, dynamic> ? parsedData : null;
    } catch (e) {
      debugPrint('Failed to get course: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>> createCourse(Map<String, dynamic> courseData) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('User ID is required');
      }
      
      // Ensure semesterId is included
      final dataWithSemester = {
        ...courseData,
        if (!courseData.containsKey('semesterId'))
          'semesterId': _authService.selectedSemesterId,
      };
      
      debugPrint('📚 Creating course for user: $userId');
      final response = await _retrofit.createCourse(userId, dataWithSemester);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      return parsedData is Map<String, dynamic> ? parsedData : {};
    } catch (e) {
      debugPrint('Failed to create course: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCourse(String courseId, Map<String, dynamic> courseData) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('User ID is required');
      }
      
      // Ensure semesterId is included
      final dataWithSemester = {
        ...courseData,
        if (!courseData.containsKey('semesterId'))
          'semesterId': _authService.selectedSemesterId,
      };
      
      debugPrint('📝 Updating course $courseId for user: $userId');
      final response = await _retrofit.updateCourse(userId, courseId, dataWithSemester);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      return parsedData is Map<String, dynamic> ? parsedData : {};
    } catch (e) {
      debugPrint('Failed to update course: $e');
      rethrow;
    }
  }

  Future<void> deleteCourse(String courseId) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('User ID is required');
      }
      
      debugPrint('🗑️ Deleting course $courseId for user: $userId');
      await _retrofit.deleteCourse(userId, courseId);
    } catch (e) {
      debugPrint('Failed to delete course: $e');
      rethrow;
    }
  }
  
  // Document endpoints
  
  Future<Map<String, dynamic>> createDocument(Map<String, dynamic> documentData) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('User ID is required');
      }
      
      // Ensure semesterId is included
      final dataWithSemester = {
        ...documentData,
        if (!documentData.containsKey('semesterId'))
          'semesterId': _authService.selectedSemesterId,
      };
      
      final response = await _retrofit.createDocument(userId, dataWithSemester);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      return parsedData is Map<String, dynamic> ? parsedData : {};
    } catch (e) {
      debugPrint('Failed to create document: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> updateDocument(String documentId, Map<String, dynamic> documentData) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('User ID is required');
      }
      
      // Ensure semesterId is included
      final dataWithSemester = {
        ...documentData,
        if (!documentData.containsKey('semesterId'))
          'semesterId': _authService.selectedSemesterId,
      };
      
      final response = await _retrofit.updateDocument(userId, documentId, dataWithSemester);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      return parsedData is Map<String, dynamic> ? parsedData : {};
    } catch (e) {
      debugPrint('Failed to update document: $e');
      rethrow;
    }
  }
  
  Future<void> deleteDocument(String documentId) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('User ID is required');
      }
      
      await _retrofit.deleteDocument(userId, documentId);
    } catch (e) {
      debugPrint('Failed to delete document: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createAssignment(String courseId, Map<String, dynamic> assignmentData) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('User ID is required');
      }
      
      final response = await _retrofit.createAssignment(userId, courseId, assignmentData);
      
      final parsedData = _parseJsonResponse(response.data);
      return parsedData is Map<String, dynamic> ? parsedData : {};
    } catch (e) {
      debugPrint('Failed to create assignment: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateAssignment(String courseId, String assignmentId, Map<String, dynamic> assignmentData) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('User ID is required');
      }
      
      final response = await _retrofit.updateAssignment(userId, courseId, assignmentId, assignmentData);
      
      final parsedData = _parseJsonResponse(response.data);
      return parsedData is Map<String, dynamic> ? parsedData : {};
    } catch (e) {
      debugPrint('Failed to update assignment: $e');
      rethrow;
    }
  }

  Future<void> deleteAssignment(String courseId, String assignmentId) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('User ID is required');
      }
      
      await _retrofit.deleteAssignment(userId, courseId, assignmentId);
      debugPrint('✅ Assignment deleted successfully');
    } catch (e) {
      debugPrint('Failed to delete assignment: $e');
      rethrow;
    }
  }

  /// Update assignment step completion status
  Future<Map<String, dynamic>> updateAssignmentStep(
    String courseId,
    String assignmentId,
    String stepId,
    Map<String, dynamic> stepData,
  ) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('User ID is required');
      }
      
      debugPrint('🔄 Updating assignment step: $stepId with data: $stepData');
      
      // Make PUT request to update step
      final dio = DioClientEnhanced(authService: _authService).dio;
      final response = await dio.put(
        '/users/$userId/courses/$courseId/assignments/$assignmentId/steps/$stepId',
        data: stepData,
      );
      
      debugPrint('✅ Step updated successfully');
      
      final parsedData = _parseJsonResponse(response.data);
      if (parsedData is Map<String, dynamic>) {
        return parsedData;
      }
      // Return a simple success response for non-object responses
      return {'success': true, 'message': parsedData?.toString() ?? 'Success'};
    } catch (e) {
      debugPrint('Failed to update assignment step: $e');
      rethrow;
    }
  }

  /// Upload attachment for an assignment
  Future<Map<String, dynamic>> uploadAttachment(
    String courseId, 
    String assignmentId, 
    File file,
    String originalFileName,
  ) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('User ID is required');
      }
      
      debugPrint('📎 Uploading attachment: ${file.path} with original name: $originalFileName');
      
      // Create a new file with the original filename to preserve the extension
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/$originalFileName');
      await file.copy(tempFile.path);
      
      try {
        final response = await _retrofit.uploadAttachment(
          userId, 
          courseId, 
          assignmentId, 
          tempFile,
        );
        
        debugPrint('✅ Attachment uploaded successfully');
        
        // Handle both direct object and JSON string responses
        if (response.data is String) {
          return json.decode(response.data);
        }
        return response.data as Map<String, dynamic>;
      } finally {
        // Clean up temp file
        try {
          await tempFile.delete();
          await tempDir.delete();
        } catch (e) {
          debugPrint('Failed to clean up temp file: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to upload attachment: $e');
      rethrow;
    }
  }

  /// Get attachments for an assignment
  Future<List<Map<String, dynamic>>> getAttachments(
    String courseId, 
    String assignmentId,
  ) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('User ID is required');
      }
      
      final response = await _retrofit.getAttachments(userId, courseId, assignmentId);
      
      final parsedData = _parseJsonResponse(response.data);
      if (parsedData is List) {
        return parsedData.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Failed to get attachments: $e');
      rethrow;
    }
  }

  /// Delete an attachment
  Future<void> deleteAttachment(
    String courseId, 
    String assignmentId, 
    String attachmentId,
  ) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('User ID is required');
      }
      
      await _retrofit.deleteAttachment(userId, courseId, assignmentId, attachmentId);
      debugPrint('✅ Attachment deleted successfully');
    } catch (e) {
      debugPrint('Failed to delete attachment: $e');
      rethrow;
    }
  }

  // Events endpoints
  
  Future<List<Map<String, dynamic>>> getEvents({
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    try {
      // Ensure user info is loaded
      if (_authService.userInfo == null) {
        debugPrint('⚠️ User info not loaded yet, loading now...');
        await _authService.loadUserInfo();
      }
      
      final userId = _getEffectiveUserId();
      if (userId == null) {
        debugPrint('❌ Cannot get events: User ID is null');
        return [];
      }
      
      // Format dates as required by API (YYYY-MM-DD HH:MM:SS.sss)
      final startAtStr = _formatDateForApi(startAt);
      final endAtStr = _formatDateForApi(endAt);
      
      debugPrint('🔄 Getting events for user $userId from $startAtStr to $endAtStr');
      final response = await _retrofit.getEvents(userId, startAtStr, endAtStr);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      if (parsedData is List) {
        final eventsList = List<Map<String, dynamic>>.from(parsedData);
        debugPrint('✅ Successfully fetched ${eventsList.length} events');
        return eventsList;
      }
      
      debugPrint('❌ No valid event data found');
      return [];
    } catch (e) {
      debugPrint('❌ Failed to get events: $e');
      return [];
    }
  }

  String _formatDateForApi(DateTime dateTime) {
    // Format as YYYY-MM-DD HH:MM:SS for API
    // Ensure we're working with local time, not UTC
    final local = dateTime.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  String _formatDateForDeadlines(DateTime dateTime) {
    // Use the same format as events API
    return _formatDateForApi(dateTime);
  }

  Future<Map<String, dynamic>?> createEvent(Map<String, dynamic> eventData) async {
    try {
      // Ensure user info is loaded
      if (_authService.userInfo == null) {
        debugPrint('⚠️ User info not loaded yet, loading now...');
        await _authService.loadUserInfo();
      }
      
      final userId = _getEffectiveUserId();
      if (userId == null) {
        debugPrint('❌ Cannot create event: User ID is null');
        return null;
      }
      
      debugPrint('🔄 Creating event for user $userId with data: $eventData');
      final response = await _retrofit.createEvent(userId, eventData);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      if (parsedData is Map<String, dynamic>) {
        debugPrint('✅ Successfully created event');
        return parsedData;
      }
      
      debugPrint('❌ No valid event data returned');
      return null;
    } catch (e) {
      debugPrint('❌ Failed to create event: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> createRecurringEvent(Map<String, dynamic> eventData) async {
    try {
      // Ensure user info is loaded
      if (_authService.userInfo == null) {
        debugPrint('⚠️ User info not loaded yet, loading now...');
        await _authService.loadUserInfo();
      }
      
      final userId = _getEffectiveUserId();
      if (userId == null) {
        debugPrint('❌ Cannot create recurring event: User ID is null');
        throw Exception('User ID is required');
      }
      
      debugPrint('🔄 Creating recurring event for user $userId with data: $eventData');
      final response = await _retrofit.createRecurringEvent(userId, eventData);
      final data = response.data;
      
      debugPrint('📊 Response status: ${response.response.statusCode}');
      debugPrint('📊 Raw response data type: ${data.runtimeType}');
      debugPrint('📊 Raw response data: $data');
      
      final parsedData = _parseJsonResponse(data);
      
      // The API might return a list of created events or a success message
      // If it returns a list, we consider it successful
      if (parsedData is List && parsedData.isNotEmpty) {
        debugPrint('✅ Successfully created ${parsedData.length} recurring events');
        return {'success': true, 'events': parsedData};
      }
      
      // If it returns a map with any data, consider it successful
      if (parsedData is Map<String, dynamic>) {
        debugPrint('✅ Successfully created recurring events');
        return parsedData;
      }
      
      // If status is 200-299 but no data, still consider it successful
      if (response.response.statusCode != null && 
          response.response.statusCode! >= 200 && 
          response.response.statusCode! < 300) {
        debugPrint('✅ Recurring events created successfully (no response body)');
        return {'success': true};
      }
      
      debugPrint('❌ No valid recurring event data returned - data: $data');
      return null;
    } catch (e) {
      debugPrint('❌ Failed to create recurring event: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>?> updateRecurringEvent(String eventId, Map<String, dynamic> eventData) async {
    try {
      // Ensure user info is loaded
      if (_authService.userInfo == null) {
        debugPrint('⚠️ User info not loaded yet, loading now...');
        await _authService.loadUserInfo();
      }
      
      final userId = _getEffectiveUserId();
      if (userId == null) {
        debugPrint('❌ Cannot update recurring event: User ID is null');
        return null;
      }
      
      debugPrint('🔄 Updating recurring event $eventId for user $userId with data: $eventData');
      final response = await _retrofit.updateRecurringEvent(userId, eventId, eventData);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      if (parsedData is Map<String, dynamic>) {
        debugPrint('✅ Successfully updated recurring event');
        return parsedData;
      }
      
      debugPrint('❌ No valid event data returned');
      return null;
    } catch (e) {
      debugPrint('❌ Failed to update recurring event: $e');
      rethrow;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      // Ensure user info is loaded
      if (_authService.userInfo == null) {
        debugPrint('⚠️ User info not loaded yet, loading now...');
        await _authService.loadUserInfo();
      }
      
      final userId = _getEffectiveUserId();
      if (userId == null) {
        debugPrint('❌ Cannot delete event: User ID is null');
        throw Exception('User ID is required');
      }
      
      debugPrint('🗑️ Deleting event $eventId for user $userId');
      await _retrofit.deleteEvent(userId, eventId);
      debugPrint('✅ Successfully deleted event');
    } catch (e) {
      debugPrint('❌ Failed to delete event: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> updateEvent(String eventId, Map<String, dynamic> eventData) async {
    try {
      // Ensure user info is loaded
      if (_authService.userInfo == null) {
        debugPrint('⚠️ User info not loaded yet, loading now...');
        await _authService.loadUserInfo();
      }
      
      final userId = _getEffectiveUserId();
      if (userId == null) {
        debugPrint('❌ Cannot update event: User ID is null');
        return null;
      }
      
      debugPrint('🔄 Updating event $eventId for user $userId with data: $eventData');
      final response = await _retrofit.updateEvent(userId, eventId, eventData);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      if (parsedData is Map<String, dynamic>) {
        debugPrint('✅ Successfully updated event');
        return parsedData;
      }
      
      debugPrint('❌ No valid event data returned');
      return null;
    } catch (e) {
      debugPrint('❌ Failed to update event: $e');
      rethrow;
    }
  }

  // Recap endpoints
  
  Future<List<Map<String, dynamic>>> getRecaps() async {
    try {
      // Ensure user info is loaded
      if (_authService.userInfo == null) {
        debugPrint('⚠️ User info not loaded yet, loading now...');
        await _authService.loadUserInfo();
      }
      
      final userId = _getEffectiveUserId();
      if (userId == null) {
        debugPrint('❌ Cannot get recaps: User ID is null');
        return [];
      }
      
      final semesterId = _authService.selectedSemesterId;
      
      debugPrint('🔄 Getting recaps for user $userId, semester $semesterId');
      final response = await _retrofit.getRecaps(userId, semesterId);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      if (parsedData is List) {
        debugPrint('✅ Successfully fetched ${parsedData.length} recaps');
        return parsedData.map<Map<String, dynamic>>((item) => 
          item is Map<String, dynamic> ? item : {}
        ).toList();
      }
      
      debugPrint('⚠️ No recaps found or invalid response format');
      return [];
    } catch (e) {
      debugPrint('❌ Failed to get recaps: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createRecap(Map<String, dynamic> recapData) async {
    try {
      // Ensure user info is loaded
      if (_authService.userInfo == null) {
        debugPrint('⚠️ User info not loaded yet, loading now...');
        await _authService.loadUserInfo();
      }
      
      final userId = _getEffectiveUserId();
      if (userId == null) {
        debugPrint('❌ Cannot create recap: User ID is null');
        return null;
      }
      
      debugPrint('🔄 Creating recap for user $userId with data: $recapData');
      final response = await _retrofit.createRecap(userId, recapData);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      if (parsedData is Map<String, dynamic>) {
        debugPrint('✅ Successfully created recap');
        return parsedData;
      }
      
      debugPrint('❌ No valid recap data returned');
      return null;
    } catch (e) {
      debugPrint('❌ Failed to create recap: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> updateRecap(String recapId, Map<String, dynamic> recapData) async {
    try {
      // Ensure user info is loaded
      if (_authService.userInfo == null) {
        debugPrint('⚠️ User info not loaded yet, loading now...');
        await _authService.loadUserInfo();
      }
      
      final userId = _getEffectiveUserId();
      if (userId == null) {
        debugPrint('❌ Cannot update recap: User ID is null');
        return null;
      }
      
      debugPrint('🔄 Updating recap $recapId for user $userId with data: $recapData');
      final response = await _retrofit.updateRecap(userId, recapId, recapData);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      if (parsedData is Map<String, dynamic>) {
        debugPrint('✅ Successfully updated recap');
        return parsedData;
      }
      
      debugPrint('❌ No valid recap data returned');
      return null;
    } catch (e) {
      debugPrint('❌ Failed to update recap: $e');
      rethrow;
    }
  }

  // Event check-in endpoint
  Future<Map<String, dynamic>?> checkInEvent(String userId, String eventId, Map<String, dynamic> locationData) async {
    try {
      debugPrint('📍 Checking in to event $eventId for user $userId with location: $locationData');
      final response = await _retrofit.checkInEvent(userId, eventId, locationData);
      final data = response.data;
      
      final parsedData = _parseJsonResponse(data);
      if (parsedData is Map<String, dynamic>) {
        debugPrint('✅ Successfully checked in to event');
        return parsedData;
      }
      
      debugPrint('❌ No valid check-in response data returned');
      return null;
    } catch (e) {
      debugPrint('❌ Failed to check in to event: $e');
      rethrow;
    }
  }
}