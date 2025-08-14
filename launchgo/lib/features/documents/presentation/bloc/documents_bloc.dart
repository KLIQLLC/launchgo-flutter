import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/usecases/get_documents.dart';
import '../../domain/usecases/search_documents.dart';
import 'documents_event.dart';
import 'documents_state.dart';

class DocumentsBloc extends Bloc<DocumentsEvent, DocumentsState> {
  final GetDocuments getDocuments;
  final SearchDocuments searchDocuments;

  DocumentsBloc({
    required this.getDocuments,
    required this.searchDocuments,
  }) : super(const DocumentsInitial()) {
    on<LoadDocuments>(_onLoadDocuments);
    on<SearchDocumentsEvent>(_onSearchDocuments);
    on<FilterDocumentsByCourse>(_onFilterDocumentsByCourse);
    on<SortDocuments>(_onSortDocuments);
  }

  Future<void> _onLoadDocuments(
    LoadDocuments event,
    Emitter<DocumentsState> emit,
  ) async {
    emit(const DocumentsLoading());
    try {
      final documents = await getDocuments();
      final sortedDocuments = _sortDocuments(documents, DocumentSortOption.lastOpened);
      emit(DocumentsLoaded(
        documents: documents,
        filteredDocuments: sortedDocuments,
      ));
    } catch (e) {
      emit(DocumentsError(e.toString()));
    }
  }

  Future<void> _onSearchDocuments(
    SearchDocumentsEvent event,
    Emitter<DocumentsState> emit,
  ) async {
    if (state is DocumentsLoaded) {
      final currentState = state as DocumentsLoaded;
      
      if (event.query.isEmpty) {
        emit(currentState.copyWith(
          filteredDocuments: _sortDocuments(currentState.documents, currentState.sortOption),
          searchQuery: '',
        ));
      } else {
        final searchResults = await searchDocuments(event.query);
        emit(currentState.copyWith(
          filteredDocuments: _sortDocuments(searchResults, currentState.sortOption),
          searchQuery: event.query,
        ));
      }
    }
  }

  void _onFilterDocumentsByCourse(
    FilterDocumentsByCourse event,
    Emitter<DocumentsState> emit,
  ) {
    if (state is DocumentsLoaded) {
      final currentState = state as DocumentsLoaded;
      
      List<DocumentEntity> filtered;
      if (event.courseId == null) {
        filtered = currentState.documents;
      } else {
        filtered = currentState.documents
            .where((doc) => doc.courseId == event.courseId)
            .toList();
      }
      
      emit(currentState.copyWith(
        filteredDocuments: _sortDocuments(filtered, currentState.sortOption),
        selectedCourseId: event.courseId,
      ));
    }
  }

  void _onSortDocuments(
    SortDocuments event,
    Emitter<DocumentsState> emit,
  ) {
    if (state is DocumentsLoaded) {
      final currentState = state as DocumentsLoaded;
      final sortedDocuments = _sortDocuments(
        currentState.filteredDocuments,
        event.sortOption,
      );
      
      emit(currentState.copyWith(
        filteredDocuments: sortedDocuments,
        sortOption: event.sortOption,
      ));
    }
  }

  List<DocumentEntity> _sortDocuments(
    List<DocumentEntity> documents,
    DocumentSortOption sortOption,
  ) {
    final sortedList = List<DocumentEntity>.from(documents);
    
    switch (sortOption) {
      case DocumentSortOption.lastOpened:
        sortedList.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
        break;
      case DocumentSortOption.title:
        sortedList.sort((a, b) => a.title.compareTo(b.title));
        break;
      case DocumentSortOption.course:
        sortedList.sort((a, b) {
          final courseA = a.courseName ?? '';
          final courseB = b.courseName ?? '';
          return courseA.compareTo(courseB);
        });
        break;
      case DocumentSortOption.type:
        sortedList.sort((a, b) => a.type.index.compareTo(b.type.index));
        break;
    }
    
    return sortedList;
  }
}