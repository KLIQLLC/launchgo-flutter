import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Event extends Equatable {
  final String id;
  final String name;
  final DateTime startAt;
  final DateTime endAt;
  final String type;
  final String? location;
  final String? description;

  const Event({
    required this.id,
    required this.name,
    required this.startAt,
    required this.endAt,
    required this.type,
    this.location,
    this.description,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      startAt: json['startAt'] != null 
          ? _parseUtcDateTime(json['startAt'])  // Parse UTC and convert to local
          : DateTime.now(),
      endAt: json['endAt'] != null 
          ? _parseUtcDateTime(json['endAt'])    // Parse UTC and convert to local
          : DateTime.now(),
      type: json['type'] ?? '',
      location: json['location'],
      description: json['description'],
    );
  }

  static DateTime _parseUtcDateTime(String dateTimeString) {
    // Ensure the string is treated as UTC if no timezone is specified
    if (!dateTimeString.endsWith('Z') && !dateTimeString.contains('+') && !dateTimeString.contains('-', 19)) {
      dateTimeString += 'Z';
    }
    return DateTime.parse(dateTimeString).toLocal();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startAt': startAt.toUtc().toIso8601String(),  // Convert to UTC before sending
      'endAt': endAt.toUtc().toIso8601String(),      // Convert to UTC before sending
      'type': type,
      if (location != null) 'location': location,
      if (description != null) 'description': description,
    };
  }

  // Get formatted time range for display
  String get timeRange {
    final startTime = _formatTime(startAt);
    final endTime = _formatTime(endAt);
    return '$startTime - $endTime';
  }

  // Get formatted time for display based on event type
  String get displayTime {
    final startTime = _formatTime(startAt);
    
    // For assignment type events, show only start time
    if (type.toLowerCase() == 'assignment') {
      return startTime;
    }
    
    // For all other events, show time range
    final endTime = _formatTime(endAt);
    return '$startTime - $endTime';
  }

  // Get color based on event type
  Color get color {
    switch (type.toLowerCase()) {
      case 'lg_session':
        return const Color(0xFFE97DE8); // Purple
      case 'class':
      case 'assignment':
        return const Color(0xFFEB4748); // Red
      case 'homework':
        return const Color(0xFF7576F0); // Blue
      case 'study':
        return const Color(0xFF5CD65C); // Green
      case 'extracurricular':
        return const Color(0xFFF6F656); // Yellow
      case 'goal':
        return const Color(0xFFADD7E6); // Baby blue
      case 'work':
        return const Color(0xFFF7BE56); // Orange
      case 'social':
        return const Color(0xFF47D1D2); // Teal
      default:
        return const Color(0xFF9C27B0); // Default to purple
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  @override
  List<Object?> get props => [id, name, startAt, endAt, type, location, description];
}