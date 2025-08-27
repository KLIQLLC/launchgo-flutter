import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:launchgo/config/environment.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:http/http.dart' as http;

class ApiService {
  final AuthService _authService;
  final String baseUrl;

  ApiService({
    required AuthService authService,
    String? baseUrl,
  }) : _authService = authService,
       baseUrl = baseUrl ?? EnvironmentConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    // The backend manages its own accessToken after exchanging serverAuthCode
    final accessToken = _authService.accessToken;
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    
    return headers;
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final accessToken = _authService.accessToken;
      
      if (accessToken == null) {
        throw Exception('No access token available. Please sign in again.');
      }
      
      final url = '$baseUrl$endpoint';
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please sign in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. You may not have permission to access this resource.');
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final accessToken = _authService.accessToken;
      
      if (accessToken == null) {
        throw Exception('No access token available. Please sign in again.');
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please sign in again.');
      } else {
        throw Exception('Failed to post data: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }


  Future<dynamic> _patch(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final accessToken = _authService.accessToken;
      
      if (accessToken == null) {
        throw Exception('No access token available. Please sign in again.');
      }
      
      final response = await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(body),
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please sign in again.');
      } else if (response.statusCode == 404) {
        throw Exception('Document not found. Status: ${response.statusCode}. Response: ${response.body}');
      } else {
        throw Exception('Failed to update data: ${response.statusCode}. Response: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final accessToken = _authService.accessToken;
      
      if (accessToken == null) {
        throw Exception('No access token available. Please sign in again.');
      }
      
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Success - no content to return
        return;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please sign in again.');
      } else {
        throw Exception('Failed to delete data: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get current user information including role and students (for mentors)
  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final accessToken = _authService.accessToken;
      if (accessToken == null) {
        throw Exception('No access token available. Please sign in again.');
      }
      
      final response = await get('/users/me');
      return response;
    } catch (e) {
      return null;
    }
  }
  
  // Test authentication endpoint
  Future<bool> testAuth() async {
    try {
      final accessToken = _authService.accessToken;
      if (accessToken == null) {
        return false;
      }
      
      // Try a simple authenticated endpoint
      try {
        await get('/user');
        return true;
      } catch (e) {
        // Try /me endpoint as fallback
        try {
          await get('/me');
          return true;
        } catch (e) {
          return false;
        }
      }
    } catch (e) {
      return false;
    }
  }

  // Get documents from backend
  Future<List<Map<String, dynamic>>> getDocuments() async {
    try {
      final accessToken = _authService.accessToken;
      if (accessToken == null) {
        throw Exception('No access token available. Please sign in again.');
      }
      
      // Get effective user ID (selected student for mentors, or current user)
      final userId = _getEffectiveUserId();
      
      // Call the documents endpoint
      final endpoint = userId != null ? '/users/$userId/documents' : '/documents';
      
      final response = await get(endpoint);
      
      // Handle different response formats
      if (response is Map<String, dynamic>) {
        // If response has a 'data' field with array
        if (response['data'] != null && response['data'] is List) {
          return List<Map<String, dynamic>>.from(response['data']);
        }
        // If response has 'documents' field
        if (response['documents'] != null && response['documents'] is List) {
          return List<Map<String, dynamic>>.from(response['documents']);
        }
        // Single document response, wrap in array
        return [response];
      } else if (response is List) {
        // Direct array response
        return List<Map<String, dynamic>>.from(response);
      }
      
      return [];
    } catch (e) {
      rethrow;
    }
  }
  
  // Create new document
  Future<Map<String, dynamic>> createDocument(Map<String, dynamic> documentData) async {
    try {
      final accessToken = _authService.accessToken;
      if (accessToken == null) {
        throw Exception('No access token available. Please sign in again.');
      }
      
      final userId = _getEffectiveUserId();
      final endpoint = '/users/$userId/documents';
      
      final response = await post(endpoint, documentData);
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  // Update existing document
  Future<Map<String, dynamic>> updateDocument(String documentId, Map<String, dynamic> documentData) async {
    try {
      final accessToken = _authService.accessToken;
      if (accessToken == null) {
        throw Exception('No access token available. Please sign in again.');
      }
      
      final userId = _getEffectiveUserId();
      final endpoint = '/users/$userId/documents/$documentId';
      
      final response = await _patch(endpoint, documentData);
      
      return response;
    } catch (e) {
      rethrow;
    }
  }
  
  // Delete document
  Future<void> deleteDocument(String documentId) async {
    try {
      final accessToken = _authService.accessToken;
      if (accessToken == null) {
        throw Exception('No access token available. Please sign in again.');
      }
      
      final userId = _getEffectiveUserId();
      if (userId == null) {
        throw Exception('Unable to determine user ID for document operation.');
      }
      
      final endpoint = '/users/$userId/documents/$documentId';
      
      await _delete(endpoint);
      
    } catch (e) {
      rethrow;
    }
  }
  
  // Get effective user ID - selected student ID for mentors, or current user ID
  String? _getEffectiveUserId() {
    final accessToken = _authService.accessToken;
    if (accessToken == null) return null;
    
    // For mentors: use selected student ID if available, otherwise fall back to mentor ID
    if (_authService.isMentor && _authService.selectedStudentId != null) {
      return _authService.selectedStudentId;
    }
    
    // For students and mentors without selected student: use user ID from token
    return _getUserIdFromToken(accessToken);
  }
  
  // Extract user ID from JWT token
  String? _getUserIdFromToken(String token) {
    try {
      if (JwtDecoder.isExpired(token)) {
        return null;
      }
      
      final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      
      // Try different possible fields for user ID
      // Priority: studentId -> mentorId -> fallback options
      var userId = decodedToken['studentId'] as String? ??
                   decodedToken['mentorId'] as String? ??
                   decodedToken['userId'] as String? ??
                   decodedToken['sub'] as String? ??
                   decodedToken['id'] as String?;
      
      // Fix malformed UUID if it has extra characters
      // Standard UUID format: 8-4-4-4-12 characters
      if (userId != null && userId.length > 36) {
        // Remove extra characters at the end if UUID is too long
        userId = userId.substring(0, 36);
      }
      return userId;
    } catch (e) {
      return null;
    }
  }
}