// features/documents/domain/entities/document_entity.dart
import 'package:equatable/equatable.dart';

enum DocumentType {
  studyGuide,
  assignment,
  notes,
}

class DocumentEntity extends Equatable {
  final String id;
  final String name;
  final String category;
  final String ownerId;
  final String fileId;
  final String? courseId; 
  final String? semesterId;
  final String link;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DocumentEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.ownerId,
    required this.fileId,
    this.courseId,
    this.semesterId,
    required this.link,
    required this.createdAt,
    required this.updatedAt,
  });

  DocumentType get type {
    switch (category) {
      case 'study-guide':
        return DocumentType.studyGuide;
      case 'assignment':
        return DocumentType.assignment;
      case 'notes':
        return DocumentType.notes;
      default:
        return DocumentType.notes; // Default to notes for unknown categories
    }
  }

  String get typeLabel {
    switch (type) {
      case DocumentType.studyGuide:
        return 'study guide';
      case DocumentType.assignment:
        return 'assignment';
      case DocumentType.notes:
        return 'notes';
    }
  }

  String get title => name;
  DateTime get lastOpened => updatedAt;
  String get googleDocsUrl => link;

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        ownerId,
        fileId,
        courseId,
        semesterId,
        link,
        createdAt,
        updatedAt,
      ];
}