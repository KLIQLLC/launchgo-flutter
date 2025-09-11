import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../api/dio_client_enhanced.dart';
import '../services/api_service_retrofit.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../widgets/extended_fab.dart';
import '../widgets/swipeable_card.dart';
import '../theme/app_colors.dart';
import '../widgets/assignment_card.dart';

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

  @override
  void initState() {
    super.initState();
    _currentCourse = widget.course;
    _loadAssignments();
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
            final coursesData = response.data is String 
                ? json.decode(response.data)['data'] 
                : response.data['data'];
            
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
      _assignments = List<Map<String, dynamic>>.from(assignments);
      
      debugPrint('Loaded ${_assignments.length} assignments');
    } catch (e) {
      debugPrint('Error loading assignments: $e');
      // Fall back to using existing course data
      final assignments = _currentCourse['assignments'] as List? ?? widget.course['assignments'] as List? ?? [];
      _assignments = List<Map<String, dynamic>>.from(assignments);
    }
    
    setState(() => _isLoading = false);
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
          onPressed: () => Navigator.of(context).pop(_hasChanges), // Return true only if changes were made
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
      child: ListView.builder(
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
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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