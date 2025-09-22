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
          ? DateTime.parse(json['startAt'])
          : DateTime.now(),
      endAt: json['endAt'] != null 
          ? DateTime.parse(json['endAt'])
          : DateTime.now(),
      type: json['type'] ?? '',
      location: json['location'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
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

  // Get color based on event type
  Color get color {
    switch (type.toLowerCase()) {
      case 'session':
        return const Color(0xFF9C88FF); // Soft purple
      case 'goal':
        return const Color(0xFF00D2D3); // Turquoise
      case 'work':
        return const Color(0xFFFF9F43); // Orange
      case 'social':
        return const Color(0xFF54A0FF); // Sky blue
      case 'class':
        return const Color(0xFFFECA57); // Yellow/Gold
      case 'homework':
        return const Color(0xFFFF6B9D); // Pink
      case 'study':
        return const Color(0xFF48DBFB); // Light blue
      case 'extracurricular':
        return const Color(0xFF5F27CD); // Deep purple
      default:
        return const Color(0xFF9C88FF); // Default to soft purple
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