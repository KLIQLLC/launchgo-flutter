import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Event extends Equatable {
  final String id;
  final String name;
  final DateTime startAt;
  final DateTime endAt;
  final String type;

  const Event({
    required this.id,
    required this.name,
    required this.startAt,
    required this.endAt,
    required this.type,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'type': type,
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
      case 'lecture':
        return const Color(0xFF6A5ACD); // Purple
      case 'study':
        return const Color(0xFF8B4513); // Brown
      case 'personal':
        return const Color(0xFF228B22); // Green
      case 'advising':
        return const Color(0xFF8B4513); // Brown
      case 'assignment':
        return const Color(0xFFFF6347); // Tomato
      default:
        return const Color(0xFF4682B4); // Steel blue
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
  List<Object?> get props => [id, name, startAt, endAt, type];
}