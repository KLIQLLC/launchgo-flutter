import '../../domain/entities/document_entity.dart';
import '../../domain/repositories/documents_repository.dart';
import '../models/document_model.dart';

class DocumentsRepositoryImpl implements DocumentsRepository {
  // Mock data for now - will be replaced with API calls
  final List<DocumentModel> _mockDocuments = [
    DocumentModel(
      id: '1',
      title: 'Biology Chapter 5 Study Guide',
      type: DocumentType.studyGuide,
      lastOpened: DateTime(2024, 1, 23),
      googleDocsUrl: 'https://docs.google.com/document/d/1',
      courseId: 'bio101',
      courseName: 'Biology 101',
    ),
    DocumentModel(
      id: '2',
      title: 'History Essay Draft',
      type: DocumentType.assignment,
      lastOpened: DateTime(2024, 1, 22),
      googleDocsUrl: 'https://docs.google.com/document/d/2',
      courseId: 'hist201',
      courseName: 'History 201',
    ),
    DocumentModel(
      id: '3',
      title: 'Math Formula Sheet',
      type: DocumentType.notes,
      lastOpened: DateTime(2024, 1, 21),
      googleDocsUrl: 'https://docs.google.com/document/d/3',
      courseId: 'math301',
      courseName: 'Math 301',
    ),
  ];

  @override
  Future<List<DocumentEntity>> getDocuments() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return List<DocumentEntity>.from(_mockDocuments);
  }

  @override
  Future<List<DocumentEntity>> getDocumentsByCourse(String courseId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockDocuments
        .where((doc) => doc.courseId == courseId)
        .toList();
  }

  @override
  Future<DocumentEntity> getDocumentById(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockDocuments.firstWhere((doc) => doc.id == id);
  }

  @override
  Future<DocumentEntity> createDocument(DocumentEntity document) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final newDocument = DocumentModel.fromEntity(document);
    _mockDocuments.add(newDocument);
    return newDocument;
  }

  @override
  Future<void> updateDocument(DocumentEntity document) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _mockDocuments.indexWhere((doc) => doc.id == document.id);
    if (index != -1) {
      _mockDocuments[index] = DocumentModel.fromEntity(document);
    }
  }

  @override
  Future<void> deleteDocument(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _mockDocuments.removeWhere((doc) => doc.id == id);
  }

  @override
  Future<List<DocumentEntity>> searchDocuments(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final lowerQuery = query.toLowerCase();
    return _mockDocuments
        .where((doc) =>
            doc.title.toLowerCase().contains(lowerQuery) ||
            (doc.courseName?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }
}