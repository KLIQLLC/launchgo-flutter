import 'dart:convert';
import 'dart:io';
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

  Future<Map<String, dynamic>> updateAssignment(String courseId, String assignmentId, Map<String, dynamic> assignmentData) async {
    try {
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('User ID is required');
      }
      
      final response = await _retrofit.updateAssignment(userId, courseId, assignmentId, assignmentData);
      
      // Handle both direct object and JSON string responses
      if (response.data is String) {
        return json.decode(response.data);
      }
      return response.data as Map<String, dynamic>;
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
      
      // Handle response - it might be a String or Map
      if (response.data is String) {
        try {
          // Try to parse as JSON if it's a string
          final parsed = json.decode(response.data);
          if (parsed is Map<String, dynamic>) {
            return parsed;
          }
        } catch (e) {
          // If parsing fails, return a simple success response
          debugPrint('Response is a plain string: ${response.data}');
        }
        // Return a success response if backend returns just a string
        return {'success': true, 'message': response.data};
      } else if (response.data is Map<String, dynamic>) {
        return response.data;
      } else {
        // Return a simple success response for other types
        return {'success': true};
      }
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
      
      // Handle both direct object and JSON string responses
      if (response.data is String) {
        final decoded = json.decode(response.data);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
        return [];
      }
      
      if (response.data is List) {
        return (response.data as List).cast<Map<String, dynamic>>();
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
}