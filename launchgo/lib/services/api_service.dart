import 'package:flutter/material.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final AuthService _authService;
  final String baseUrl;

  ApiService({
    required AuthService authService,
    this.baseUrl = 'https://your-api-endpoint.com',
  }) : _authService = authService;

  Future<Map<String, String>> _getHeaders() async {
    // The backend manages its own sessions after exchanging serverAuthCode
    final sessionToken = _authService.sessionToken;
    
    return {
      'Content-Type': 'application/json',
      if (sessionToken != null) 'Authorization': 'Bearer $sessionToken',
    };
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
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
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
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
}