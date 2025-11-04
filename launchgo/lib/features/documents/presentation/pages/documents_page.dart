import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/api_service_retrofit.dart';
import '../../../../services/theme_service.dart';
import '../../../../widgets/cupertino_dropdown.dart';
import '../../../../widgets/extended_fab.dart';
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
        final apiService = ApiServiceRetrofit(authService: authService);
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
  final ScrollController _scrollController = ScrollController();
  String? _previousSelectedSemesterId;
  String? _previousSelectedStudentId;
  String? _targetDocumentId;
  bool _hasScrolledToTarget = false;
  
  // Cell/line/section parameters for enhanced highlighting
  String? _targetCellId;
  int? _targetLineNumber;
  String? _targetSectionId;

  @override
  void initState() {
    super.initState();
    
    // Check for scroll target from navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Check both extra data and query parameters
      final routerState = GoRouterState.of(context);
      final extra = routerState.extra as Map<String, dynamic>?;
      String? targetDocumentId;
      
      // First try extra data (for programmatic navigation)
      if (extra != null && extra['scrollToDocumentId'] != null) {
        targetDocumentId = extra['scrollToDocumentId'] as String;
      }
      // Then try query parameters (for URL-based navigation)
      else if (routerState.uri.queryParameters['scrollToDocumentId'] != null) {
        targetDocumentId = routerState.uri.queryParameters['scrollToDocumentId'];
        
        // Also extract cell/line/section parameters
        _targetCellId = routerState.uri.queryParameters['cellId'];
        _targetLineNumber = int.tryParse(routerState.uri.queryParameters['line'] ?? '');
        _targetSectionId = routerState.uri.queryParameters['section'];
      }
      
      if (targetDocumentId != null) {
        _targetDocumentId = targetDocumentId;
        _hasScrolledToTarget = false; // Reset scroll flag for new target
        
        String debugMessage = '🔔 Documents: Target document ID set: $_targetDocumentId';
        if (_targetCellId != null) debugMessage += ', cellId: $_targetCellId';
        if (_targetLineNumber != null) debugMessage += ', line: $_targetLineNumber';
        if (_targetSectionId != null) debugMessage += ', section: $_targetSectionId';
        debugPrint(debugMessage);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    final bloc = context.read<DocumentsBloc>();
    _searchController.clear();
    
    bloc.add(const LoadDocuments());
    
    // Wait for the loading to complete by listening to state changes
    await bloc.stream.firstWhere((state) => state is! DocumentsLoading);
  }
  
  /// Scroll to a specific document card and highlight it
  void _scrollToAndHighlightDocument(GlobalKey key) {
    // Prevent multiple scroll attempts for the same target
    if (_hasScrolledToTarget) return;
    
    try {
      // Wait a bit longer to ensure widget is fully rendered
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        
        final context = key.currentContext;
        if (context != null) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null && renderBox.hasSize) {
            final position = renderBox.localToGlobal(Offset.zero);
            final scrollPosition = _scrollController.offset + position.dy - 150; // Better offset calculation
            
            debugPrint('🔔 Scrolling to document at position: $scrollPosition');
            
            _scrollController.animateTo(
              scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
            
            _hasScrolledToTarget = true; // Mark as scrolled to prevent multiple attempts
            
            // Show cell/line/section information if available
            if (_targetCellId != null || _targetLineNumber != null || _targetSectionId != null) {
              String message = 'Document located';
              if (_targetCellId != null) {
                message += ' • Cell: $_targetCellId';
              }
              if (_targetLineNumber != null) {
                message += ' • Line: $_targetLineNumber';
              }
              if (_targetSectionId != null) {
                message += ' • Section: $_targetSectionId';
              }
              
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: const Color(0xFF4CAF50), // Success green
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              });
            }
            
            // Clear the highlight after 3 seconds
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _targetDocumentId = null;
                  _targetCellId = null;
                  _targetLineNumber = null;
                  _targetSectionId = null;
                  _hasScrolledToTarget = false; // Reset for next target
                });
                debugPrint('🔔 Document highlight cleared');
              }
            });
          } else {
            debugPrint('⚠️ RenderBox not ready, retrying...');
            // Retry once if renderBox isn't ready
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted && !_hasScrolledToTarget) {
                _scrollToAndHighlightDocument(key);
              }
            });
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Error scrolling to document: $e');
      _hasScrolledToTarget = false; // Reset on error
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final authService = context.watch<AuthService>();
    
    // Check if semester or student changed and trigger documents reload
    final currentSemesterId = authService.selectedSemesterId;
    final currentStudentId = authService.selectedStudentId;
    
    bool shouldReload = false;
    
    if (_previousSelectedSemesterId != currentSemesterId && currentSemesterId != null) {
      _previousSelectedSemesterId = currentSemesterId;
      shouldReload = true;
    }
    
    if (_previousSelectedStudentId != currentStudentId && currentStudentId != null) {
      _previousSelectedStudentId = currentStudentId;
      shouldReload = true;
      debugPrint('🔄 Selected student changed to: $currentStudentId - reloading documents');
    }
    
    if (shouldReload) {
      // Trigger reload after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<DocumentsBloc>().add(const LoadDocuments());
      });
    }
    
    return Scaffold(
      backgroundColor: themeService.backgroundColor,
      floatingActionButton: authService.permissions.canCreateDocuments 
        ? ExtendedFAB(
            label: 'New Document',
            onPressed: () async {
              // Navigate to new document screen
              final result = await context.push('/new-document');
              if (result == true && context.mounted) {
                // Refresh documents list if document was created successfully
                _onRefresh();
              }
            },
          )
        : null, // Hide FAB for students
      body: SafeArea(
        child: Column(
          children: [
            Divider(color: themeService.borderColor, height: 1),
            Expanded(
              child: RefreshIndicator(
                backgroundColor: themeService.cardColor,
                color: ThemeService.accent,
                onRefresh: _onRefresh,
                child: SingleChildScrollView(
                  controller: _scrollController,
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
                    style: TextStyle(color: themeService.inputTextColor),
                    decoration: InputDecoration(
                      hintText: 'Search documents...',
                      hintStyle: TextStyle(color: themeService.inputPlaceholderColor),
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
                          final key = GlobalKey();
                          final isTargetDocument = _targetDocumentId != null && document.id == _targetDocumentId;
                          
                          // Check if this is the target document to scroll to
                          if (isTargetDocument && !_hasScrolledToTarget) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _scrollToAndHighlightDocument(key);
                            });
                          }
                          
                          return AnimatedContainer(
                            key: key,
                            duration: const Duration(milliseconds: 500),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: isTargetDocument
                                  ? Border.all(color: Colors.orange, width: 2)
                                  : null,
                              boxShadow: isTargetDocument
                                  ? [
                                      BoxShadow(
                                        color: Colors.orange.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                            child: DocumentCard(
                              document: document,
                              onDeleted: _onRefresh,
                            ),
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
                            color: AppColors.error,
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
      ),
    );
  }
}