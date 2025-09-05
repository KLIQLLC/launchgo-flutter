import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/services/api_service_retrofit.dart';
import 'package:provider/provider.dart';
import '../widgets/course_card.dart';
import '../widgets/extended_fab.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = false;
  String? _previousSelectedSemesterId;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiServiceRetrofit(authService: authService);
      
      final courses = await apiService.getCourses();
      if (mounted) {
        setState(() {
          _courses = courses;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateToAddCourse() async {
    final result = await context.push('/new-course');
    
    if (result == true && mounted) {
      _loadCourses();
    }
  }

  Future<void> _navigateToEditCourse(Map<String, dynamic> course) async {
    final result = await context.push(
      '/edit-course/${course['id']}',
      extra: course,
    );
    
    if (result == true && mounted) {
      _loadCourses();
    }
  }

  Future<void> _navigateToAddAssignment(Map<String, dynamic> course) async {
    final result = await context.push(
      '/course/${course['id']}/assignments/new',
      extra: course,
    );
    
    if (result == true && mounted) {
      _loadCourses();
    }
  }

  Future<void> _deleteCourse(String courseId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiServiceRetrofit(authService: authService);
      
      await apiService.deleteCourse(courseId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCourses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete course: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _confirmDelete(BuildContext context, String courseName) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Course'),
          content: Text('Are you sure you want to delete "$courseName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final authService = context.watch<AuthService>();
    
    // Check if semester changed and trigger courses reload
    final currentSemesterId = authService.selectedSemesterId;
    if (_previousSelectedSemesterId != currentSemesterId && currentSemesterId != null) {
      _previousSelectedSemesterId = currentSemesterId;
      // Trigger reload after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCourses();
      });
    }
    
    return Scaffold(
      backgroundColor: themeService.backgroundColor,
      floatingActionButton: authService.permissions.canCreateDocuments 
        ? ExtendedFAB(
            label: 'New Course',
            onPressed: _navigateToAddCourse,
          )
        : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? _buildEmptyState(themeService)
              : _buildCoursesList(themeService),
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
              child: SvgPicture.asset(
                'assets/icons/ic_course.svg',
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
              'No Courses Yet',
              style: TextStyle(
                color: themeService.textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your enrolled courses will appear here\nonce they are available',
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

  Widget _buildCoursesList(ThemeService themeService) {
    final authService = context.watch<AuthService>();
    final canDelete = authService.permissions.canDeleteDocuments;
    
    return RefreshIndicator(
      onRefresh: _loadCourses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _courses.length,
        itemBuilder: (context, index) {
          final course = _courses[index];
          
          // Only wrap in Dismissible if user has permission to delete
          if (canDelete) {
            return Dismissible(
              key: Key(course['id']?.toString() ?? index.toString()),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) async {
                return await _confirmDelete(context, course['name'] ?? 'this course');
              },
              onDismissed: (direction) {
                if (course['id'] != null) {
                  _deleteCourse(course['id']);
                }
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              child: CourseCard(
                course: course,
                themeService: themeService,
                onTap: authService.permissions.canEditDocuments 
                  ? () => _navigateToEditCourse(course)
                  : null,
                onAssignmentsTap: () => _navigateToAddAssignment(course),
              ),
            );
          } else {
            return CourseCard(
              course: course,
              themeService: themeService,
              onTap: authService.permissions.canEditDocuments 
                ? () => _navigateToEditCourse(course)
                : null,
              onAssignmentsTap: () => _navigateToAddAssignment(course),
            );
          }
        },
      ),
    );
  }
}