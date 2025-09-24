import 'package:equatable/equatable.dart';

class DeadlineAttachment extends Equatable {
  final String id;
  final String name;
  final String link;
  final int size;
  final String mimeType;

  const DeadlineAttachment({
    required this.id,
    required this.name,
    required this.link,
    required this.size,
    required this.mimeType,
  });

  factory DeadlineAttachment.fromJson(Map<String, dynamic> json) {
    return DeadlineAttachment(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      link: json['link'] ?? '',
      size: json['size'] ?? 0,
      mimeType: json['mimeType'] ?? '',
    );
  }

  @override
  List<Object?> get props => [id, name, link, size, mimeType];
}

class DeadlineAssignment extends Equatable {
  final String id;
  final String title;
  final DateTime dueDate;
  final String status;
  final List<DeadlineAttachment> attachments;

  const DeadlineAssignment({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.status,
    required this.attachments,
  });

  factory DeadlineAssignment.fromJson(Map<String, dynamic> json) {
    return DeadlineAssignment(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      dueDate: json['dueDateAt'] != null 
          ? DateTime.parse(json['dueDateAt']).toLocal()  // Convert UTC to local timezone
          : DateTime.now(),
      status: json['status'] ?? 'pending',
      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
              .map((a) => DeadlineAttachment.fromJson(a))
              .toList()
          : [],
    );
  }

  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isOverdue => !isCompleted && dueDate.toUtc().isBefore(DateTime.now().toUtc());

  @override
  List<Object?> get props => [id, title, dueDate, status, attachments];
}

class DeadlineCourse extends Equatable {
  final String id;
  final String code;
  final List<DeadlineAssignment> assignments;

  const DeadlineCourse({
    required this.id,
    required this.code,
    required this.assignments,
  });

  factory DeadlineCourse.fromJson(Map<String, dynamic> json) {
    return DeadlineCourse(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      assignments: json['assignments'] != null
          ? (json['assignments'] as List)
              .map((a) => DeadlineAssignment.fromJson(a))
              .toList()
          : [],
    );
  }

  @override
  List<Object?> get props => [id, code, assignments];
}