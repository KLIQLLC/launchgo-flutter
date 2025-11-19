import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../utils/recurrence_utils.dart';

class Event extends Equatable {
  final String id;
  final String name;
  final DateTime startEventAt;
  final DateTime endEventAt;
  final String type;
  final String? addressLocation;
  final double? longLocation;
  final double? latLocation;
  final String? checkInLocationStatus;
  final String? description;
  final String? recurrenceType;
  final DateTime? startRecurrenceAt;
  final DateTime? endRecurrenceAt;
  final bool isRecurrence;

  const Event({
    required this.id,
    required this.name,
    required this.startEventAt,
    required this.endEventAt,
    required this.type,
    this.addressLocation,
    this.longLocation,
    this.latLocation,
    this.checkInLocationStatus,
    this.description,
    this.recurrenceType,
    this.startRecurrenceAt,
    this.endRecurrenceAt,
    this.isRecurrence = false,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      startEventAt: _getStartDateTime(json),  // Handle both old and new field names
      endEventAt: _getEndDateTime(json),      // Handle both old and new field names
      type: json['type'] ?? '',
      addressLocation: json['addressLocation'],
      longLocation: json['longLocation'] != null ? double.tryParse(json['longLocation'].toString()) : null,
      latLocation: json['latLocation'] != null ? double.tryParse(json['latLocation'].toString()) : null,
      checkInLocationStatus: json['checkInLocationStatus'],
      description: json['description'],
      recurrenceType: json['recurrenceType'],
      startRecurrenceAt: json['startRecurrenceAt'] != null ? _parseUtcDateTime(json['startRecurrenceAt']) : null,
      endRecurrenceAt: json['endRecurrenceAt'] != null ? _parseUtcDateTime(json['endRecurrenceAt']) : null,
      isRecurrence: json['isRecurrence'] ?? false,
    );
  }

  static DateTime _getStartDateTime(Map<String, dynamic> json) {
    // Try new API field name first, then fall back to old field name
    final startEventAt = json['startEventAt'];
    final startAt = json['startAt'];
    
    if (startEventAt != null) {
      return _parseUtcDateTime(startEventAt);
    } else if (startAt != null) {
      return _parseUtcDateTime(startAt);
    } else {
      return DateTime.now();
    }
  }

  static DateTime _getEndDateTime(Map<String, dynamic> json) {
    // Try new API field name first, then fall back to old field name
    final endEventAt = json['endEventAt'];
    final endAt = json['endAt'];
    
    if (endEventAt != null) {
      return _parseUtcDateTime(endEventAt);
    } else if (endAt != null) {
      return _parseUtcDateTime(endAt);
    } else {
      return DateTime.now();
    }
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
      'startEventAt': startEventAt.toUtc().toIso8601String(),
      'endEventAt': endEventAt.toUtc().toIso8601String(),
      'type': type,
      if (addressLocation != null) 'addressLocation': addressLocation,
      if (longLocation != null) 'longLocation': longLocation.toString(),
      if (latLocation != null) 'latLocation': latLocation.toString(),
      if (checkInLocationStatus != null) 'checkInLocationStatus': checkInLocationStatus,
      if (description != null) 'description': description,
      if (recurrenceType != null) 'recurrenceType': recurrenceType,
      if (startRecurrenceAt != null) 'startRecurrenceAt': startRecurrenceAt!.toUtc().toIso8601String(),
      if (endRecurrenceAt != null) 'endRecurrenceAt': endRecurrenceAt!.toUtc().toIso8601String(),
      'isRecurrence': isRecurrence,
    };
  }

  // Get formatted time range for display
  String get timeRange {
    final startTime = _formatTime(startEventAt);
    final endTime = _formatTime(endEventAt);
    return '$startTime - $endTime';
  }

  // Get formatted time for display based on event type
  String get displayTime {
    final startTime = _formatTime(startEventAt);
    
    // For assignment type events, show only start time
    if (type.toLowerCase() == 'assignment') {
      return startTime;
    }
    
    // For all other events, show time range
    final endTime = _formatTime(endEventAt);
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

  // Helper methods for recurring events
  bool get isRecurringEvent => isRecurrence;
  bool get isSingleEvent => !isRecurrence;
  
  String get recurrenceTypeFormatted {
    return RecurrenceUtils.formatType(recurrenceType);
  }

  @override
  List<Object?> get props => [id, name, startEventAt, endEventAt, type, addressLocation, longLocation, latLocation, checkInLocationStatus, description, recurrenceType, startRecurrenceAt, endRecurrenceAt, isRecurrence];
}