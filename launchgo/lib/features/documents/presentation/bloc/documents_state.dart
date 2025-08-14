import 'package:equatable/equatable.dart';
import '../../domain/entities/document_entity.dart';
import 'documents_event.dart';

abstract class DocumentsState extends Equatable {
  const DocumentsState();

  @override
  List<Object?> get props => [];
}

class DocumentsInitial extends DocumentsState {
  const DocumentsInitial();
}

class DocumentsLoading extends DocumentsState {
  const DocumentsLoading();
}

class DocumentsLoaded extends DocumentsState {
  final List<DocumentEntity> documents;
  final List<DocumentEntity> filteredDocuments;
  final String searchQuery;
  final String? selectedCourseId;
  final DocumentSortOption sortOption;

  const DocumentsLoaded({
    required this.documents,
    required this.filteredDocuments,
    this.searchQuery = '',
    this.selectedCourseId,
    this.sortOption = DocumentSortOption.lastOpened,
  });

  @override
  List<Object?> get props => [
        documents,
        filteredDocuments,
        searchQuery,
        selectedCourseId,
        sortOption,
      ];

  DocumentsLoaded copyWith({
    List<DocumentEntity>? documents,
    List<DocumentEntity>? filteredDocuments,
    String? searchQuery,
    String? selectedCourseId,
    DocumentSortOption? sortOption,
  }) {
    return DocumentsLoaded(
      documents: documents ?? this.documents,
      filteredDocuments: filteredDocuments ?? this.filteredDocuments,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCourseId: selectedCourseId,
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

class DocumentsError extends DocumentsState {
  final String message;

  const DocumentsError(this.message);

  @override
  List<Object?> get props => [message];
}