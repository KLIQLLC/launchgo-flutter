import '../entities/document_entity.dart';
import '../repositories/documents_repository.dart';

class SearchDocuments {
  final DocumentsRepository repository;

  SearchDocuments(this.repository);

  Future<List<DocumentEntity>> call(String query) async {
    if (query.isEmpty) {
      return await repository.getDocuments();
    }
    return await repository.searchDocuments(query);
  }
}