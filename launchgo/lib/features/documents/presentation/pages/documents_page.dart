import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../../../services/auth_service.dart';
import '../../data/repositories/documents_repository_impl.dart';
import '../../domain/usecases/get_documents.dart';
import '../../domain/usecases/search_documents.dart';
import '../bloc/documents_bloc.dart';
import '../bloc/documents_event.dart';
import '../bloc/documents_state.dart';
import '../widgets/document_card.dart';

class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final repository = DocumentsRepositoryImpl();
        return DocumentsBloc(
          getDocuments: GetDocuments(repository),
          searchDocuments: SearchDocuments(repository),
        )..add(const LoadDocuments());
      },
      child: const DocumentsView(),
    );
  }
}

class DocumentsView extends StatefulWidget {
  const DocumentsView({super.key});

  @override
  State<DocumentsView> createState() => _DocumentsViewState();
}

class _DocumentsViewState extends State<DocumentsView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1318),
      appBar: AppBar(
        title: const Text(
          'Documents & Study Guides',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0F1318),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Divider(color: Color(0xFF2A303E), height: 1),
            // Documents Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      context
                          .read<DocumentsBloc>()
                          .add(SearchDocumentsEvent(value));
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search documents...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A1F2B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF2A303E),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF2A303E),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF7B8CDE),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Sort Dropdown
                  Row(
                    children: [
                      Text(
                        'Filter by course:',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F2B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF2A303E),
                            width: 1,
                          ),
                        ),
                        child: BlocBuilder<DocumentsBloc, DocumentsState>(
                          builder: (context, state) {
                            final sortOption = state is DocumentsLoaded
                                ? state.sortOption
                                : DocumentSortOption.course;
                            
                            return DropdownButton<DocumentSortOption>(
                              value: sortOption,
                              isDense: true,
                              onChanged: (option) {
                                if (option != null) {
                                  context
                                      .read<DocumentsBloc>()
                                      .add(SortDocuments(option));
                                }
                              },
                              underline: const SizedBox(),
                              dropdownColor: const Color(0xFF1A1F2B),
                              icon: const Icon(
                                Icons.expand_more,
                                color: Colors.white,
                                size: 18,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: DocumentSortOption.course,
                                  child: Text('All'),
                                ),
                                DropdownMenuItem(
                                  value: DocumentSortOption.lastOpened,
                                  child: Text('CODE11'),
                                ),
                                DropdownMenuItem(
                                  value: DocumentSortOption.title,
                                  child: Text('CODE12'),
                                ),
                                DropdownMenuItem(
                                  value: DocumentSortOption.type,
                                  child: Text('CODE13'),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Documents List
            BlocBuilder<DocumentsBloc, DocumentsState>(
                builder: (context, state) {
                  if (state is DocumentsLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7B8CDE),
                      ),
                    );
                  } else if (state is DocumentsLoaded) {
                    if (state.filteredDocuments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              color: Colors.white.withOpacity(0.3),
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No documents found',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: state.filteredDocuments.map((document) {
                          return DocumentCard(
                            document: document,
                          );
                        }).toList(),
                      ),
                    );
                  } else if (state is DocumentsError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.withOpacity(0.7),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${state.message}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              context
                                  .read<DocumentsBloc>()
                                  .add(const LoadDocuments());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7B8CDE),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return const SizedBox();
                },
              ),
              const SizedBox(height: 80), // Space for FAB
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement new document
        },
        backgroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Document'),
      ),
    );
  }
}