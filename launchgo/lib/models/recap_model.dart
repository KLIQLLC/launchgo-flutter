import 'package:equatable/equatable.dart';

class Recap extends Equatable {
  final String id;
  final String title;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String semesterId;
  final String studentId;
  final String creatorId;
  final String? studentName;

  const Recap({
    required this.id,
    required this.title,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.semesterId,
    required this.studentId,
    required this.creatorId,
    this.studentName,
  });

  factory Recap.fromJson(Map<String, dynamic> json) {
    return Recap(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      notes: json['notes'] ?? '',
      createdAt: json['createdAt'] != null
          ? _parseDateTime(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? _parseDateTime(json['updatedAt'])
          : DateTime.now(),
      semesterId: json['semesterId'] ?? '',
      studentId: json['studentId'] ?? '',
      creatorId: json['creatorId'] ?? '',
      studentName: json['studentName'],
    );
  }

  static DateTime _parseDateTime(String dateTimeString) {
    // Handle the format "2025-09-30 02:23:40.000"
    if (dateTimeString.contains(' ')) {
      dateTimeString = dateTimeString.replaceFirst(' ', 'T');
    }
    // Ensure the string is treated as UTC if no timezone is specified
    if (!dateTimeString.endsWith('Z') && !dateTimeString.contains('+') && !dateTimeString.contains('-', 19)) {
      dateTimeString += 'Z';
    }
    return DateTime.parse(dateTimeString).toLocal();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'semesterId': semesterId,
      'studentId': studentId,
      'creatorId': creatorId,
      if (studentName != null) 'studentName': studentName,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        notes,
        createdAt,
        updatedAt,
        semesterId,
        studentId,
        creatorId,
        studentName,
      ];
}