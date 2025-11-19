import '../../domain/entities/document_entity.dart';
import '../../domain/repositories/documents_repository.dart';
import '../models/document_model.dart';
import '../../../../services/api_service_retrofit.dart';

class DocumentsRepositoryImpl implements DocumentsRepository {
  final ApiServiceRetrofit _apiService;

  DocumentsRepositoryImpl({required ApiServiceRetrofit apiService}) : _apiService = apiService;

  @override
  Future<List<DocumentEntity>> getDocuments() async {
    try {
      final documentsData = await _apiService.getDocuments();
      return documentsData.map((json) => DocumentModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch documents: $e');
    }
  }

  @override
  Future<List<DocumentEntity>> getDocumentsByCourse(String courseId) async {
    try {
      final allDocuments = await getDocuments();
      return allDocuments.where((doc) => doc.courseId == courseId).toList();
    } catch (e) {
      throw Exception('Failed to fetch documents by course: $e');
    }
  }

  @override
  Future<DocumentEntity> getDocumentById(String id) async {
    try {
      final allDocuments = await getDocuments();
      return allDocuments.firstWhere((doc) => doc.id == id);
    } catch (e) {
      throw Exception('Failed to fetch document by id: $e');
    }
  }

  @override
  Future<DocumentEntity> createDocument(DocumentEntity document) async {
    // TODO: Implement API call for creating documents
    throw UnimplementedError('Create document not implemented yet');
  }

  @override
  Future<void> updateDocument(DocumentEntity document) async {
    // TODO: Implement API call for updating documents
    throw UnimplementedError('Update document not implemented yet');
  }

  @override
  Future<void> deleteDocument(String id) async {
    // TODO: Implement API call for deleting documents
    throw UnimplementedError('Delete document not implemented yet');
  }

  @override
  Future<List<DocumentEntity>> searchDocuments(String query) async {
    try {
      final allDocuments = await getDocuments();
      final lowerQuery = query.toLowerCase();
      return allDocuments
          .where((doc) =>
              doc.name.toLowerCase().contains(lowerQuery) ||
              doc.category.toLowerCase().contains(lowerQuery))
          .toList();
    } catch (e) {
      throw Exception('Failed to search documents: $e');
    }
  }
}