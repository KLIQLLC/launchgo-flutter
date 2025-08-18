import '../../domain/entities/document_entity.dart';

class DocumentModel extends DocumentEntity {
  const DocumentModel({
    required super.id,
    required super.name,
    required super.category,
    required super.ownerId,
    required super.fileId,
    super.courseId,
    required super.link,
    required super.createdAt,
    required super.updatedAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      ownerId: json['ownerId'] as String,
      fileId: json['fileId'] as String,
      courseId: json['courseId'] as String?,
      link: json['link'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'ownerId': ownerId,
      'fileId': fileId,
      'courseId': courseId,
      'link': link,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DocumentModel.fromEntity(DocumentEntity entity) {
    return DocumentModel(
      id: entity.id,
      name: entity.name,
      category: entity.category,
      ownerId: entity.ownerId,
      fileId: entity.fileId,
      courseId: entity.courseId,
      link: entity.link,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}