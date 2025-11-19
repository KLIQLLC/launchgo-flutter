import '../entities/document_entity.dart';
import '../repositories/documents_repository.dart';

class GetDocuments {
  final DocumentsRepository repository;

  GetDocuments(this.repository);

  Future<List<DocumentEntity>> call() async {
    return await repository.getDocuments();
  }
}