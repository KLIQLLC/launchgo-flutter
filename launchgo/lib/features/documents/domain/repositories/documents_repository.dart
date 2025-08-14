import '../entities/document_entity.dart';

abstract class DocumentsRepository {
  Future<List<DocumentEntity>> getDocuments();
  Future<List<DocumentEntity>> getDocumentsByCourse(String courseId);
  Future<DocumentEntity> getDocumentById(String id);
  Future<DocumentEntity> createDocument(DocumentEntity document);
  Future<void> updateDocument(DocumentEntity document);
  Future<void> deleteDocument(String id);
  Future<List<DocumentEntity>> searchDocuments(String query);
}