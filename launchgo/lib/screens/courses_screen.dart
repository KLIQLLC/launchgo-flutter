import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/services/api_service_retrofit.dart';
import 'package:provider/provider.dart';
import 'course_form_screen.dart';
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
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CourseFormScreen(),
      ),
    );
    
    if (result == true) {
      _loadCourses();
    }
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
    return RefreshIndicator(
      onRefresh: _loadCourses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _courses.length,
        itemBuilder: (context, index) {
          final course = _courses[index];
          return CourseCard(
            course: course,
            themeService: themeService,
          );
        },
      ),
    );
  }
}