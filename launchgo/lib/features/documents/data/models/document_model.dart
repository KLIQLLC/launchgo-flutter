import '../../domain/entities/document_entity.dart';

class DocumentModel extends DocumentEntity {
  const DocumentModel({
    required super.id,
    required super.title,
    required super.type,
    required super.lastOpened,
    super.googleDocsUrl,
    super.courseId,
    super.courseName,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      title: json['title'] as String,
      type: _parseDocumentType(json['type'] as String),
      lastOpened: DateTime.parse(json['lastOpened'] as String),
      googleDocsUrl: json['googleDocsUrl'] as String?,
      courseId: json['courseId'] as String?,
      courseName: json['courseName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type.toString().split('.').last,
      'lastOpened': lastOpened.toIso8601String(),
      'googleDocsUrl': googleDocsUrl,
      'courseId': courseId,
      'courseName': courseName,
    };
  }

  static DocumentType _parseDocumentType(String type) {
    switch (type) {
      case 'studyGuide':
        return DocumentType.studyGuide;
      case 'assignment':
        return DocumentType.assignment;
      case 'notes':
        return DocumentType.notes;
      default:
        return DocumentType.other;
    }
  }

  factory DocumentModel.fromEntity(DocumentEntity entity) {
    return DocumentModel(
      id: entity.id,
      title: entity.title,
      type: entity.type,
      lastOpened: entity.lastOpened,
      googleDocsUrl: entity.googleDocsUrl,
      courseId: entity.courseId,
      courseName: entity.courseName,
    );
  }
}