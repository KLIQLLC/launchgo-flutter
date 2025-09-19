import 'package:flutter/material.dart';
import 'package:launchgo/models/deadline_model.dart';
import 'package:launchgo/models/user_model.dart';
import 'package:launchgo/screens/edit_student_info_modal.dart';
import 'package:launchgo/services/api_service_retrofit.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:launchgo/widgets/deadline_card.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const _weekDuration = Duration(days: 7);
  static const _endOfWeekOffset = Duration(days: 6);
  
  List<DeadlineCourse> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _currentWeekStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeWeekStart();
    _loadDeadlines();
  }

  void _initializeWeekStart() {
    final now = DateTime.now();
    _currentWeekStart = now.subtract(Duration(days: now.weekday % 7));
  }

  Future<void> _loadDeadlines() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = context.read<ApiServiceRetrofit>();
      final endOfWeek = _currentWeekStart.add(_endOfWeekOffset);

      final response = await apiService.getDeadlines(
        startAt: _currentWeekStart.millisecondsSinceEpoch,
        endAt: endOfWeek.millisecondsSinceEpoch,
      );

      if (response != null && response['data'] != null) {
        final List<dynamic> coursesData = response['data'];
        setState(() {
          _courses = coursesData
              .map((c) => DeadlineCourse.fromJson(c))
              .toList();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load deadlines. Please try again.';
      });
      debugPrint('Error loading deadlines: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateWeek(int weekOffset) {
    setState(() {
      _currentWeekStart = weekOffset > 0
          ? _currentWeekStart.add(_weekDuration)
          : _currentWeekStart.subtract(_weekDuration);
    });
    _loadDeadlines();
  }

  List<MapEntry<DeadlineCourse, DeadlineAssignment>> _getSortedAssignments() {
    final assignments = <MapEntry<DeadlineCourse, DeadlineAssignment>>[];
    
    for (final course in _courses) {
      for (final assignment in course.assignments) {
        assignments.add(MapEntry(course, assignment));
      }
    }
    
    assignments.sort((a, b) => a.value.dueDate.compareTo(b.value.dueDate));
    return assignments;
  }

  String _getWeekRangeText() {
    final endOfWeek = _currentWeekStart.add(_endOfWeekOffset);
    final startFormat = DateFormat('MMM d');
    final endFormat = DateFormat('MMM d, yyyy');
    return '${startFormat.format(_currentWeekStart)} - ${endFormat.format(endOfWeek)}';
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final authService = context.watch<AuthService>();

    return Column(
      children: [
        _StudentHeader(authService: authService, themeService: themeService),
        Expanded(
          child: Container(
            color: const Color(0xFF0F1419),
            child: _buildContent(themeService),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeService themeService) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _ErrorState(
        message: _errorMessage!,
        onRetry: _loadDeadlines,
        themeService: themeService,
      );
    }

    return _DeadlinesList(
      assignments: _getSortedAssignments(),
      weekRangeText: _getWeekRangeText(),
      onPreviousWeek: () => _navigateWeek(-1),
      onNextWeek: () => _navigateWeek(1),
      themeService: themeService,
    );
  }
}

class _StudentHeader extends StatelessWidget {
  final AuthService authService;
  final ThemeService themeService;

  const _StudentHeader({
    required this.authService,
    required this.themeService,
  });

  @override
  Widget build(BuildContext context) {
    final userInfo = authService.userInfo;
    final displayedStudent = authService.getSelectedStudent();
    final displayName = userInfo?.isMentor == true && displayedStudent != null
        ? displayedStudent.name
        : userInfo?.name ?? 'Student';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        border: Border(
          bottom: BorderSide(
            color: themeService.borderColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _StudentInfo(
            student: displayedStudent ?? userInfo,
          ),
        ],
      ),
    );
  }
}

class _StudentInfo extends StatelessWidget {
  final dynamic student;

  const _StudentInfo({required this.student});

  String get academicYear {
    String? year;
    if (student is Student) {
      year = student.academicYear;
    } else if (student is UserModel && student.students.isNotEmpty) {
      year = student.students.first.academicYear;
    }
    
    // Normalize the academic year (capitalize first letter)
    if (year != null && year.isNotEmpty) {
      final lower = year.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }
    return 'Sophomore';
  }

  String get gpa {
    double? gpaValue;
    if (student is Student) {
      gpaValue = student.gpa;
    } else if (student is UserModel && student.students.isNotEmpty) {
      gpaValue = student.students.first.gpa;
    }
    return gpaValue != null ? gpaValue.toStringAsFixed(1) : '2.4';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await EditStudentInfoModal.show(context);
        
        // If the edit was successful, the screen will rebuild automatically
        // since AuthService will notify listeners
        if (result == true) {
          debugPrint('Student info updated successfully');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Year: $academicYear',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '•',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'GPA: $gpa',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeadlinesList extends StatelessWidget {
  final List<MapEntry<DeadlineCourse, DeadlineAssignment>> assignments;
  final String weekRangeText;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final ThemeService themeService;

  const _DeadlinesList({
    required this.assignments,
    required this.weekRangeText,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.themeService,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _WeekNavigator(
            onPreviousWeek: onPreviousWeek,
            onNextWeek: onNextWeek,
          ),
          const SizedBox(height: 32),
          _buildAssignmentsList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming Deadlines',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          weekRangeText,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentsList() {
    if (assignments.isEmpty) {
      return _EmptyState(
        message: 'No deadlines for this week',
        themeService: themeService,
      );
    }

    // Group assignments by course code
    Map<String, List<MapEntry<DeadlineCourse, DeadlineAssignment>>> groupedAssignments = {};
    for (final entry in assignments) {
      final courseCode = entry.key.code;
      if (!groupedAssignments.containsKey(courseCode)) {
        groupedAssignments[courseCode] = [];
      }
      groupedAssignments[courseCode]!.add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedAssignments.entries.map((courseGroup) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course header
            Padding(
              padding: const EdgeInsets.only(left: 0, bottom: 16),
              child: Text(
                courseGroup.key,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Assignments for this course
            ...courseGroup.value.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DeadlineCard(
                  assignment: entry.value,
                  course: entry.key,
                ),
              );
            }),
            const SizedBox(height: 16), // Space between course groups
          ],
        );
      }).toList(),
    );
  }
}

class _WeekNavigator extends StatelessWidget {
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  const _WeekNavigator({
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NavigationButton(
          label: 'Previous',
          onPressed: onPreviousWeek,
        ),
        const SizedBox(width: 12),
        _NavigationButton(
          label: 'Next',
          onPressed: onNextWeek,
        ),
      ],
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _NavigationButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      child: Text(label),
    );
  }
}


class _EmptyState extends StatelessWidget {
  final String message;
  final ThemeService themeService;

  const _EmptyState({
    required this.message,
    required this.themeService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 48,
              color: themeService.textTertiaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: themeService.textSecondaryColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final ThemeService themeService;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.themeService,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: themeService.textTertiaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Error',
              style: TextStyle(
                color: themeService.textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: themeService.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}