import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/api_service.dart';
import '../../../../services/theme_service.dart';
import '../../../../widgets/cupertino_dropdown.dart';
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
                      SizedBox(
                        width: 120, // Fixed width for the dropdown
                        child: BlocBuilder<DocumentsBloc, DocumentsState>(
                          builder: (context, state) {
                            // Get current selected course
                            String getCurrentCourse() {
                              if (state is DocumentsLoaded) {
                                // If no course is selected (null), it means "All"
                                return state.selectedCourseId ?? 'All';
                              }
                              return 'All';
                            }
                            
                            return CupertinoDropdown(
                              value: getCurrentCourse(),
                              items: const ['All', 'CODE11', 'CODE12', 'CODE13'],
                              hintText: 'Select course',
                              onChanged: (course) {
                                  if (course != null) {
                                    // Filter by course
                                    if (course == 'All') {
                                      // Show all documents - no filter
                                      context.read<DocumentsBloc>().add(const FilterDocumentsByCourse(null));
                                    } else {
                                      // Filter by specific course
                                      context.read<DocumentsBloc>().add(FilterDocumentsByCourse(course));
                                    }
                                  }
                                },
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
                        color: ThemeService.accent,
                      ),
                    );
                  } else if (state is DocumentsLoaded) {
                    if (state.filteredDocuments.isEmpty) {
                      // Check if it's empty due to search or no documents at all
                      final bool isSearching = _searchController.text.isNotEmpty;
                      final bool hasNoDocuments = state.documents.isEmpty;
                      // Check if "All" courses is selected (null selectedCourseId means "All")
                      final bool isAllCoursesSelected = state.selectedCourseId == null;
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: themeService.cardColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: themeService.borderColor,
                                    width: 1,
                                  ),
                                ),
                                child: isSearching 
                                  ? Icon(
                                      Icons.search_off,
                                      color: themeService.textTertiaryColor,
                                      size: 48,
                                    )
                                  : SvgPicture.asset(
                                      'assets/icons/ic_document.svg',
                                      width: 48,
                                      height: 48,
                                      colorFilter: ColorFilter.mode(
                                        themeService.textTertiaryColor,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                isSearching 
                                  ? 'No results found'
                                  : hasNoDocuments
                                    ? 'No documents yet'
                                    : isAllCoursesSelected
                                      ? 'No documents yet'  // This should only show if filtered docs are empty when "All" is selected
                                      : 'No documents in this course',
                                style: TextStyle(
                                  color: themeService.textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isSearching 
                                  ? 'Try adjusting your search terms'
                                  : hasNoDocuments
                                    ? 'Your documents will appear here\nonce they are uploaded'
                                    : isAllCoursesSelected
                                      ? 'Your documents will appear here\nonce they are uploaded'
                                      : 'Select a different course or\ncheck back later for updates',
                                style: TextStyle(
                                  color: themeService.textSecondaryColor,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (isSearching) ...[
                                const SizedBox(height: 24),
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    context.read<DocumentsBloc>().add(const SearchDocumentsEvent(''));
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: ThemeService.accent,
                                  ),
                                  child: const Text('Clear search'),
                                ),
                              ],
                            ],
                          ),
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