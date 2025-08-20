import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/api_service.dart';
import '../../../../services/theme_service.dart';
import '../../../../widgets/course_filter_selector.dart';
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
        final authService = Provider.of<AuthService>(context, listen: false);
        final apiService = ApiService(authService: authService);
        final repository = DocumentsRepositoryImpl(apiService: apiService);
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

  Future<void> _onRefresh() async {
    final bloc = context.read<DocumentsBloc>();
    _searchController.clear();
    
    bloc.add(const LoadDocuments());
    
    // Wait for the loading to complete by listening to state changes
    await bloc.stream.firstWhere((state) => state is! DocumentsLoading);
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    
    return SafeArea(
        child: Column(
          children: [
            Divider(color: themeService.borderColor, height: 1),
            Expanded(
              child: RefreshIndicator(
                backgroundColor: themeService.cardColor,
                color: ThemeService.accent,
                onRefresh: _onRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                  children: [
                    // Documents Section
                    Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar
                  SizedBox(
                    height: 40,
                    child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      context
                          .read<DocumentsBloc>()
                          .add(SearchDocumentsEvent(value));
                    },
                    style: TextStyle(color: themeService.textColor),
                    decoration: InputDecoration(
                      hintText: 'Search documents...',
                      hintStyle: TextStyle(color: themeService.textTertiaryColor),
                      prefixIcon: Icon(
                        Icons.search,
                        color: themeService.textTertiaryColor,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: themeService.cardColor,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: themeService.borderColor,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: themeService.borderColor,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: ThemeService.accent,
                          width: 1,
                        ),
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
                          color: themeService.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      BlocBuilder<DocumentsBloc, DocumentsState>(
                        builder: (context, state) {
                          // Map sort options to course names for display
                          String getCurrentCourse() {
                            if (state is DocumentsLoaded) {
                              switch (state.sortOption) {
                                case DocumentSortOption.course:
                                  return 'All';
                                case DocumentSortOption.lastOpened:
                                  return 'CODE11';
                                case DocumentSortOption.title:
                                  return 'CODE12';
                                case DocumentSortOption.type:
                                  return 'CODE13';
                                default:
                                  return 'All';
                              }
                            }
                            return 'All';
                          }
                          
                          return CourseFilterSelector(
                            initialCourse: getCurrentCourse(),
                            courses: const ['All', 'CODE11', 'CODE12', 'CODE13'],
                            onCourseChanged: (course) {
                              // Map course selection back to sort option
                              DocumentSortOption option;
                              switch (course) {
                                case 'All':
                                  option = DocumentSortOption.course;
                                  break;
                                case 'CODE11':
                                  option = DocumentSortOption.lastOpened;
                                  break;
                                case 'CODE12':
                                  option = DocumentSortOption.title;
                                  break;
                                case 'CODE13':
                                  option = DocumentSortOption.type;
                                  break;
                                default:
                                  option = DocumentSortOption.course;
                              }
                              context.read<DocumentsBloc>().add(SortDocuments(option));
                            },
                          );
                        },
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
                        color: ThemeService.accent,
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
                              color: themeService.textTertiaryColor,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No documents found',
                              style: TextStyle(
                                color: themeService.textSecondaryColor,
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
                            color: Colors.red,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${state.message}',
                            style: TextStyle(
                              color: themeService.textSecondaryColor,
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
                              backgroundColor: ThemeService.accent,
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
            ),
          ],
        ),
      );
  }
}