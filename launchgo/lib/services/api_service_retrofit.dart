import 'dart:convert';
import 'package:dio/dio.dart';
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
  Map<String, dynamic> _parseResponse(Map<String, dynamic> response) {
    // Handle cases where the response might be a string
    if (response.containsKey('data') && response['data'] is String) {
      try {
        response['data'] = json.decode(response['data']);
      } catch (e) {
        debugPrint('❌ Failed to parse response data as JSON: $e');
      }
    }
    return response;
  }
  
  // User endpoints
  
  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final response = await _retrofit.getUserInfo();
      final data = response.data;
      
      // Parse JSON string response for getUserInfo
      if (data is String) {
        final parsedData = json.decode(data);
        if (parsedData['data'] != null) {
          return parsedData['data'];
        }
        return parsedData;
      } else if (data is Map<String, dynamic>) {
        final parsed = _parseResponse(data);
        if (parsed['data'] != null) {
          return parsed['data'];
        }
        return parsed;
      }
      
      return null;
    } catch (e) {
      debugPrint('Failed to get user info: $e');
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
      
      // Parse JSON string response for semesters
      if (data is String) {
        final parsedData = json.decode(data);
        if (parsedData['data'] is List) {
          final semesterList = List<Map<String, dynamic>>.from(parsedData['data']);
          debugPrint('✅ Successfully parsed ${semesterList.length} semesters');
          return semesterList;
        }
      }
      
      debugPrint('❌ No valid semester data found');
      return [];
    } catch (e) {
      debugPrint('❌ Failed to get semesters: $e');
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
      
      // Parse JSON string response for getDocuments
      if (data is String) {
        final parsedData = json.decode(data);
        if (parsedData['data'] is List) {
          return List<Map<String, dynamic>>.from(parsedData['data']);
        }
      } else if (data is Map<String, dynamic>) {
        final parsed = _parseResponse(data);
        // Handle different response formats
        if (parsed['data'] != null && parsed['data'] is List) {
          return List<Map<String, dynamic>>.from(parsed['data']);
        }
        if (parsed['documents'] != null && parsed['documents'] is List) {
          return List<Map<String, dynamic>>.from(parsed['documents']);
        }
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
      
      // Parse JSON string response for getCourses
      if (data is String) {
        final parsedData = json.decode(data);
        if (parsedData['data'] is List) {
          return List<Map<String, dynamic>>.from(parsedData['data']);
        }
      } else if (data is Map<String, dynamic>) {
        final parsed = _parseResponse(data);
        if (parsed['data'] != null && parsed['data'] is List) {
          return List<Map<String, dynamic>>.from(parsed['data']);
        }
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
      
      // Parse JSON string response if needed
      if (data is String) {
        final parsedData = json.decode(data);
        if (parsedData['data'] != null) {
          return parsedData['data'] as Map<String, dynamic>;
        }
        return parsedData as Map<String, dynamic>;
      } else if (data is Map<String, dynamic>) {
        final parsed = _parseResponse(data);
        if (parsed['data'] != null) {
          return parsed['data'] as Map<String, dynamic>;
        }
        return parsed;
      }
      
      return null;
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
      
      // Parse JSON string response
      if (data is String) {
        final parsedData = json.decode(data);
        if (parsedData['data'] != null) {
          return parsedData['data'];
        }
        return parsedData;
      } else if (data is Map<String, dynamic>) {
        final parsed = _parseResponse(data);
        if (parsed['data'] != null) {
          return parsed['data'];
        }
        return parsed;
      }
      
      return {};
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
      
      // Parse JSON string response
      if (data is String) {
        final parsedData = json.decode(data);
        if (parsedData['data'] != null) {
          return parsedData['data'];
        }
        return parsedData;
      } else if (data is Map<String, dynamic>) {
        final parsed = _parseResponse(data);
        if (parsed['data'] != null) {
          return parsed['data'];
        }
        return parsed;
      }
      
      return {};
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
      
      if (data is Map<String, dynamic>) {
        return _parseResponse(data);
      }
      return {};
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
      
      if (data is Map<String, dynamic>) {
        return _parseResponse(data);
      }
      return {};
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
      
      // Handle both direct object and JSON string responses
      if (response.data is String) {
        return json.decode(response.data);
      }
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to create assignment: $e');
      rethrow;
    }
  }
}