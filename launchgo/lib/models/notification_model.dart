import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  final String id;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  final String? uploadedBy;
  final String? fileName;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
    this.metadata,
    this.uploadedBy,
    this.fileName,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? json['message'] ?? '',
      message: json['message'] ?? json['body'] ?? '',
      type: json['type'] ?? 'general',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      isRead: _parseBool(json['isRead'] ?? json['is_read'] ?? false),
      metadata: json['data'] != null 
          ? json['data'] as Map<String, dynamic>
          : json['metadata'] as Map<String, dynamic>?,
      uploadedBy: json['uploadedBy'] ?? json['uploaded_by'] ?? 
          (json['data'] != null ? json['data']['mentorName'] : null),
      fileName: json['fileName'] ?? json['file_name'] ?? 
          (json['data'] != null ? json['data']['documentName'] ?? json['data']['eventName'] : null),
    );
  }

  /// Helper method to parse boolean values from API response
  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'metadata': metadata,
      'uploadedBy': uploadedBy,
      'fileName': fileName,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? metadata,
    String? uploadedBy,
    String? fileName,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      fileName: fileName ?? this.fileName,
    );
  }

  @override
  List<Object?> get props => [
    id, title, message, type, createdAt, isRead, metadata, uploadedBy, fileName
  ];
}