import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../api/dio_client_enhanced.dart';
import '../../services/api_service_retrofit.dart';
import '../../services/theme_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/extended_fab.dart';
import '../../widgets/swipeable_card.dart';
import '../../theme/app_colors.dart';
import '../../widgets/documents/assignment_card.dart';

class AssignmentsScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  
  const AssignmentsScreen({super.key, required this.course});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = false;
  Map<String, dynamic> _currentCourse = {};
  bool _hasChanges = false; // Track if any assignments were modified
  String? _lastSelectedStudentId; // Track current student to detect changes
  final ScrollController _scrollController = ScrollController();
  String? _targetAssignmentId;
  bool _hasScrolledToTarget = false;
  
  // Cell/line/section parameters for enhanced highlighting
  String? _targetCellId;
  int? _targetLineNumber;
  String? _targetSectionId;

  @override
  void initState() {
    super.initState();
    _currentCourse = widget.course;
    _loadAssignments();
    
    // Check for scroll target from navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Check both extra data and query parameters
      final routerState = GoRouterState.of(context);
      final extra = routerState.extra as Map<String, dynamic>?;
      String? targetAssignmentId;
      
      // First try extra data (for programmatic navigation)
      if (extra != null && extra['scrollToAssignmentId'] != null) {
        targetAssignmentId = extra['scrollToAssignmentId'] as String;
      }
      // Then try query parameters (for URL-based navigation)
      else if (routerState.uri.queryParameters['scrollToAssignmentId'] != null) {
        targetAssignmentId = routerState.uri.queryParameters['scrollToAssignmentId'];
        
        // Also extract cell/line/section parameters
        _targetCellId = routerState.uri.queryParameters['cellId'];
        _targetLineNumber = int.tryParse(routerState.uri.queryParameters['line'] ?? '');
        _targetSectionId = routerState.uri.queryParameters['section'];
      }
      
      if (targetAssignmentId != null) {
        _targetAssignmentId = targetAssignmentId;
        _hasScrolledToTarget = false; // Reset scroll flag for new target
        
        String debugMessage = '🔔 Assignments: Target assignment ID set: $_targetAssignmentId';
        if (_targetCellId != null) debugMessage += ', cellId: $_targetCellId';
        if (_targetLineNumber != null) debugMessage += ', line: $_targetLineNumber';
        if (_targetSectionId != null) debugMessage += ', section: $_targetSectionId';
        debugPrint(debugMessage);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check if selected student has changed
    final authService = context.watch<AuthService>();
    final currentStudentId = authService.selectedStudentId;
    
    if (_lastSelectedStudentId != currentStudentId) {
      _lastSelectedStudentId = currentStudentId;
      
      // Only reload if this isn't the initial load (which happens in initState)
      if (_lastSelectedStudentId != null) {
        debugPrint('🔄 Selected student changed to: $currentStudentId - reloading assignments');
        _loadAssignments();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll to a specific assignment card and highlight it
  void _scrollToAndHighlightAssignment(GlobalKey key) {
    // Prevent multiple scroll attempts for the same target
    if (_hasScrolledToTarget) return;
    
    try {
      // Wait a bit longer to ensure widget is fully rendered
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        
        final keyContext = key.currentContext;
        if (keyContext != null) {
          final renderBox = keyContext.findRenderObject() as RenderBox?;
          if (renderBox != null && renderBox.hasSize) {
            final position = renderBox.localToGlobal(Offset.zero);
            final scrollPosition = _scrollController.offset + position.dy - 150; // Better offset calculation
            
            debugPrint('🔔 Scrolling to assignment at position: $scrollPosition');
            
            _scrollController.animateTo(
              scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
            
            _hasScrolledToTarget = true; // Mark as scrolled to prevent multiple attempts
            
            // Show cell/line/section information if available
            if (_targetCellId != null || _targetLineNumber != null || _targetSectionId != null) {
              String message = 'Assignment located';
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
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  scaffoldMessenger.showSnackBar(
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
                  _targetAssignmentId = null;
                  _targetCellId = null;
                  _targetLineNumber = null;
                  _targetSectionId = null;
                  _hasScrolledToTarget = false; // Reset for next target
                });
                debugPrint('🔔 Assignment highlight cleared');
              }
            });
          } else {
            debugPrint('⚠️ RenderBox not ready, retrying...');
            // Retry once if renderBox isn't ready
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted && !_hasScrolledToTarget) {
                _scrollToAndHighlightAssignment(key);
              }
            });
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Error scrolling to assignment: $e');
      _hasScrolledToTarget = false; // Reset on error
    }
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);
    
    try {
      // Try to fetch updated course data from API to get latest assignments
      final authService = Provider.of<AuthService>(context, listen: false);
      final courseId = _currentCourse['id'] ?? widget.course['id'];
      
      if (courseId != null) {
        // Get updated courses list which includes assignments
        final userId = authService.userInfo?.isMentor == true && authService.selectedStudentId != null 
            ? authService.selectedStudentId 
            : authService.userInfo?.id;
        final semesterId = authService.selectedSemesterId;
        
        if (userId != null && semesterId != null) {
          debugPrint('🔄 Refreshing course data for assignments...');
          
          // Make API call to get courses (which includes assignments)
          final dio = DioClientEnhanced(authService: authService).dio;
          final response = await dio.get('/users/$userId/courses?semesterId=$semesterId');
          
          if (response.data != null) {
            // API returns direct array of courses
            final coursesData = response.data is String 
                ? json.decode(response.data)
                : response.data;
            
            // Find our specific course in the updated data
            final updatedCourse = (coursesData as List).firstWhere(
              (course) => course['id'] == courseId,
              orElse: () => _currentCourse,
            );
            
            _currentCourse = updatedCourse;
            debugPrint('✅ Course data refreshed');
          }
        }
      }
      
      // Get assignments from the updated course data
      final assignments = _currentCourse['assignments'] as List? ?? [];
      final newAssignments = List<Map<String, dynamic>>.from(assignments);
      
      
      setState(() {
        _assignments = newAssignments;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading assignments: $e');
      // Fall back to using existing course data
      final assignments = _currentCourse['assignments'] as List? ?? widget.course['assignments'] as List? ?? [];
      final fallbackAssignments = List<Map<String, dynamic>>.from(assignments);
      
      setState(() {
        _assignments = fallbackAssignments;
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToAddAssignment() async {
    final result = await context.push(
      '/course/${widget.course['id']}/assignments/new',
      extra: widget.course,
    );
    
    if (result == true && mounted) {
      // Refresh assignments after creating new one
      _hasChanges = true;
      _loadAssignments();
    }
  }





  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final authService = context.watch<AuthService>();
    
    return Scaffold(
      backgroundColor: themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeService.backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '${_currentCourse['name'] ?? widget.course['name']} • ${_currentCourse['code'] ?? widget.course['code']}',
          style: TextStyle(
            color: themeService.textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeService.textColor),
          onPressed: () {
            // Check if we can pop the navigation stack
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(_hasChanges); // Return true only if changes were made
            } else {
              // If no navigation stack (opened via notification), go to courses
              context.go('/courses');
            }
          },
        ),
      ),
      floatingActionButton: authService.permissions.canCreateDocuments 
        ? ExtendedFAB(
            label: 'Add Assignment',
            onPressed: _navigateToAddAssignment,
          )
        : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
              ? _buildEmptyState(themeService)
              : _buildAssignmentsList(themeService),
    );
  }

  Widget _buildEmptyState(ThemeService themeService) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
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
              child: Icon(
                Icons.assignment_outlined,
                size: 48,
                color: themeService.textTertiaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Assignments Yet',
              style: TextStyle(
                color: themeService.textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Course assignments will appear here\nonce they are added',
              style: TextStyle(
                color: themeService.textSecondaryColor,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentsList(ThemeService themeService) {
    return RefreshIndicator(
      onRefresh: () async => _loadAssignments(),
      color: ThemeService.accent,
      backgroundColor: themeService.cardColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _assignments.length,
        itemBuilder: (context, index) {
          final assignment = _assignments[index];
          return _buildAssignmentCard(assignment, themeService);
        },
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment, ThemeService themeService) {
    final authService = context.watch<AuthService>();
    final key = GlobalKey();
    final isTargetAssignment = _targetAssignmentId != null && assignment['id'] == _targetAssignmentId;
    
    // Check if this is the target assignment to scroll to
    if (isTargetAssignment && !_hasScrolledToTarget) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAndHighlightAssignment(key);
      });
    }
    
    return AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isTargetAssignment
            ? Border.all(color: Colors.orange, width: 2)
            : null,
        boxShadow: isTargetAssignment
            ? [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: SwipeableCard(
        canSwipe: authService.permissions.canDeleteDocuments,
        canTap: true, // Allow all users to open assignments
        onTap: () => _navigateToEditAssignment(assignment),
        onSwipeToDelete: () => _showDeleteConfirmation(assignment),
        child: AssignmentCard(
          assignment: assignment,
          course: widget.course,
          themeService: themeService,
          onTap: () => _navigateToEditAssignment(assignment),
          onDelete: () => _showDeleteConfirmation(assignment),
          canEdit: true, // Allow all users to open assignments
          canDelete: authService.permissions.canDeleteDocuments,
        ),
      ),
    );
  }

  Future<void> _navigateToEditAssignment(Map<String, dynamic> assignment) async {
    final result = await context.push(
      '/course/${widget.course['id']}/assignments/${assignment['id']}/edit',
      extra: {
        'course': widget.course,
        'assignment': assignment,
      },
    );
    
    if (result == true && mounted) {
      // Refresh assignments list after editing
      _hasChanges = true;
      _loadAssignments();
    }
  }

  Future<bool> _showDeleteConfirmation(Map<String, dynamic> assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: Text('Are you sure you want to delete "${assignment['title']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      await _deleteAssignment(assignment);
      return true;
    }
    return false;
  }

  Future<void> _deleteAssignment(Map<String, dynamic> assignment) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiServiceRetrofit(authService: authService);
      
      await apiService.deleteAssignment(
        widget.course['id'].toString(),
        assignment['id'].toString(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // Refresh assignments list after deletion
        _hasChanges = true;
        _loadAssignments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete assignment: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}