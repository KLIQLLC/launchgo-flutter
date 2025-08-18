import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:http/http.dart' as http;

class ApiService {
  final AuthService _authService;
  final String baseUrl;

  ApiService({
    required AuthService authService,
    this.baseUrl = 'https://paqlhj8bef.execute-api.us-west-1.amazonaws.com/api',
  }) : _authService = authService;

  Future<Map<String, String>> _getHeaders() async {
    // The backend manages its own accessToken after exchanging serverAuthCode
    final accessToken = _authService.accessToken;
    
    return {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final accessToken = _authService.accessToken;
      
      if (accessToken == null) {
        throw Exception('No access token available. Please sign in again.');
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please sign in again.');
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

  // Get documents from backend
  Future<List<Map<String, dynamic>>> getDocuments() async {
    try {
      final accessToken = _authService.accessToken;
      if (accessToken == null) {
        throw Exception('No access token available. Please sign in again.');
      }
      
      // Extract user ID from JWT token
      final userId = _getUserIdFromToken(accessToken);
      if (userId == null) {
        throw Exception('Unable to get user ID from token');
      }
      
      final response = await get('/users/$userId/documents');
      if (response['data'] != null) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
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
      return decodedToken['studentId'] as String?;
    } catch (e) {
      debugPrint('Error extracting user ID from token: $e');
      return null;
    }
  }
}