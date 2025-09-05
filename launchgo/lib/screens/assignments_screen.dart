import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../services/api_service_retrofit.dart';
import '../widgets/extended_fab.dart';

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

  @override
  void initState() {
    super.initState();
    _currentCourse = widget.course;
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);
    
    try {
      // Try to fetch updated course data from API
      final apiService = context.read<ApiServiceRetrofit>();
      final courseId = _currentCourse['id'] ?? widget.course['id'];
      
      if (courseId != null) {
        final updatedCourse = await apiService.getCourse(courseId);
        if (updatedCourse != null) {
          _currentCourse = updatedCourse;
        }
      }
      
      // Get assignments from the course data
      final assignments = _currentCourse['assignments'] as List? ?? [];
      _assignments = List<Map<String, dynamic>>.from(assignments);
    } catch (e) {
      debugPrint('Error loading assignments: $e');
      // Fall back to using the assignments from the widget
      final assignments = _currentCourse['assignments'] as List? ?? [];
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
      // TODO: Refresh assignments from API
      _loadAssignments();
    }
  }

  String _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return '#4CAF50'; // Green
      case 'in_progress':
        return '#FF9800'; // Orange
      case 'overdue':
        return '#F44336'; // Red
      default:
        return '#9E9E9E'; // Grey for pending
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'in_progress':
        return 'IN PROGRESS';
      case 'completed':
        return 'COMPLETED';
      case 'overdue':
        return 'OVERDUE';
      default:
        return 'PENDING';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'No due date';
    
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid date';
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
          '${_currentCourse['name'] ?? widget.course['name']} - ${_currentCourse['code'] ?? widget.course['code']}',
          style: TextStyle(
            color: themeService.textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeService.textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: authService.permissions.canCreateDocuments 
        ? ExtendedFAB(
            label: 'New Assignment',
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
    final statusColor = Color(int.parse(_getStatusColor(assignment['status']).substring(1), radix: 16) + 0xFF000000);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: themeService.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeService.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assignment header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment['title'] ?? 'Untitled Assignment',
                        style: TextStyle(
                          color: themeService.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (assignment['description'] != null && assignment['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          assignment['description'],
                          style: TextStyle(
                            color: themeService.textSecondaryColor,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getStatusText(assignment['status']),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Assignment details
            Row(
              children: [
                // Due date
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: themeService.textSecondaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Due: ${_formatDate(assignment['dueDateAt'])}',
                  style: TextStyle(
                    color: themeService.textSecondaryColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 16),
                // Points
                Icon(
                  Icons.stars,
                  size: 16,
                  color: themeService.textSecondaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '${assignment['pointsEarned'] ?? 0}/${assignment['pointsGoal'] ?? 0} pts',
                  style: TextStyle(
                    color: themeService.textSecondaryColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}