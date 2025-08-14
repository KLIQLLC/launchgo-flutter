import 'package:equatable/equatable.dart';

abstract class DocumentsEvent extends Equatable {
  const DocumentsEvent();

  @override
  List<Object?> get props => [];
}

class LoadDocuments extends DocumentsEvent {
  const LoadDocuments();
}

class SearchDocumentsEvent extends DocumentsEvent {
  final String query;

  const SearchDocumentsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class FilterDocumentsByCourse extends DocumentsEvent {
  final String? courseId;

  const FilterDocumentsByCourse(this.courseId);

  @override
  List<Object?> get props => [courseId];
}

class SortDocuments extends DocumentsEvent {
  final DocumentSortOption sortOption;

  const SortDocuments(this.sortOption);

  @override
  List<Object?> get props => [sortOption];
}

enum DocumentSortOption {
  course,
  lastOpened,
  title,
  type,
}