import 'package:equatable/equatable.dart';

enum DocumentType {
  studyGuide,
  assignment,
  notes,
  other,
}

class DocumentEntity extends Equatable {
  final String id;
  final String title;
  final DocumentType type;
  final DateTime lastOpened;
  final String? googleDocsUrl;
  final String? courseId;
  final String? courseName;

  const DocumentEntity({
    required this.id,
    required this.title,
    required this.type,
    required this.lastOpened,
    this.googleDocsUrl,
    this.courseId,
    this.courseName,
  });

  String get typeLabel {
    switch (type) {
      case DocumentType.studyGuide:
        return 'study guide';
      case DocumentType.assignment:
        return 'assignment';
      case DocumentType.notes:
        return 'notes';
      case DocumentType.other:
        return 'other';
    }
  }

  @override
  List<Object?> get props => [
        id,
        title,
        type,
        lastOpened,
        googleDocsUrl,
        courseId,
        courseName,
      ];
}