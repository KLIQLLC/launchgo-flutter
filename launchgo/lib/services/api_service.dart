import 'dart:convert';
import 'package:flutter/material.dart';
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
      debugPrint('accessToken: $accessToken');
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
      debugPrint('API GET Request: $url');
      debugPrint('Headers: $headers');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint('Response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('Response body: ${response.body}');
      }

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
      debugPrint('API GET error: $e');
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
      debugPrint('API POST error: $e');
      rethrow;
    }
  }

  // Example: Get user profile from your backend
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final response = await get('/user/profile');
      return response;
    } catch (e) {
      debugPrint('Failed to get user profile: $e');
      return null;
    }
  }
  
  // Test authentication endpoint
  Future<bool> testAuth() async {
    try {
      debugPrint('=== Testing Authentication ===');
      debugPrint('Environment: ${EnvironmentConfig.environmentName}');
      debugPrint('Base URL: $baseUrl');
      
      final accessToken = _authService.accessToken;
      if (accessToken == null) {
        debugPrint('No access token available');
        return false;
      }
      
      // Decode and display token info
      try {
        final decodedToken = JwtDecoder.decode(accessToken);
        debugPrint('Token claims: $decodedToken');
        debugPrint('Token expiry: ${JwtDecoder.getExpirationDate(accessToken)}');
        debugPrint('Token is expired: ${JwtDecoder.isExpired(accessToken)}');
      } catch (e) {
        debugPrint('Failed to decode token: $e');
      }
      
      // Try a simple authenticated endpoint
      try {
        final response = await get('/user');
        debugPrint('Test auth successful: $response');
        return true;
      } catch (e) {
        debugPrint('Test auth failed with /user: $e');
      }
      
      // Try /me endpoint
      try {
        final response = await get('/me');
        debugPrint('Test auth successful with /me: $response');
        return true;
      } catch (e) {
        debugPrint('Test auth failed with /me: $e');
      }
      
      return false;
    } catch (e) {
      debugPrint('Test auth error: $e');
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
      
      debugPrint('=== Getting Documents ===');
      debugPrint('Environment: ${EnvironmentConfig.environmentName}');
      debugPrint('Base URL: $baseUrl');
      
      // Extract user ID from JWT token
      // final userId = _getUserIdFromToken(accessToken);
      //hardcoded userId for testing
      final userId = "e0a6da47-7328-4f48-bbbb-964e75eb7838";
      debugPrint('User ID from token: $userId');
      
      // Call the documents endpoint
      final endpoint = userId != null ? '/users/$userId/documents' : '/documents';
      debugPrint('Calling endpoint: $endpoint');
      
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
      
      debugPrint('Unexpected response format: ${response.runtimeType}');
      return [];
    } catch (e) {
      debugPrint('Failed to get documents: $e');
      rethrow;
    }
  }
  
  // Extract user ID from JWT token
  String? _getUserIdFromToken(String token) {
    try {
      if (JwtDecoder.isExpired(token)) {
        debugPrint('JWT token is expired');
        return null;
      }
      
      final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      debugPrint('Decoded token claims: $decodedToken');
      
      // Try different possible fields for user ID
      var userId = decodedToken['studentId'] as String? ??
                   decodedToken['userId'] as String? ??
                   decodedToken['sub'] as String? ??
                   decodedToken['id'] as String?;
      
      // Fix malformed UUID if it has extra characters
      // Standard UUID format: 8-4-4-4-12 characters
      if (userId != null && userId.length > 36) {
        debugPrint('Detected malformed UUID: $userId');
        // Remove extra characters at the end if UUID is too long
        userId = userId.substring(0, 36);
        debugPrint('Fixed UUID: $userId');
      }
      
      debugPrint('Extracted user ID: $userId');
      return userId;
    } catch (e) {
      debugPrint('Error extracting user ID from token: $e');
      return null;
    }
  }
}