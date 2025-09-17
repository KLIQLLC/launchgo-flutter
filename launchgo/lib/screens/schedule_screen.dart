import 'package:flutter/material.dart';
import 'package:launchgo/models/deadline_model.dart';
import 'package:launchgo/models/user_model.dart';
import 'package:launchgo/services/api_service_retrofit.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/services/theme_service.dart';
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
    if (student is Student) {
      return student.academicYear ?? 'Sophomore';
    }
    if (student?.students != null && student.students.isNotEmpty) {
      return student.students.first.academicYear ?? 'Sophomore';
    }
    return 'Sophomore';
  }

  String get gpa {
    if (student is Student) {
      final gpa = student.gpa;
      return gpa != null ? gpa.toStringAsFixed(1) : '2.4';
    }
    if (student?.students != null && student.students.isNotEmpty) {
      final gpa = student.students.first.gpa;
      return gpa != null ? gpa.toStringAsFixed(1) : '2.4';
    }
    return '2.4';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
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
          '• GPA: $gpa',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
          ),
        ),
      ],
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

    return Column(
      children: assignments.map((entry) {
        return _AssignmentItem(
          course: entry.key,
          assignment: entry.value,
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

class _AssignmentItem extends StatelessWidget {
  final DeadlineCourse course;
  final DeadlineAssignment assignment;

  const _AssignmentItem({
    required this.course,
    required this.assignment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          course.code,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _AssignmentCard(assignment: assignment),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final DeadlineAssignment assignment;

  const _AssignmentCard({required this.assignment});

  Color get _borderColor {
    if (assignment.isCompleted) return Colors.green;
    if (assignment.isOverdue) return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: _borderColor,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _StatusIcon(isCompleted: assignment.isCompleted),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            assignment.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (assignment.isCompleted) _StatusBadge.completed(),
        if (assignment.isOverdue) _StatusBadge.overdue(),
        if (assignment.attachments.isNotEmpty)
          _AttachmentIndicator(count: assignment.attachments.length),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Text(
          'Due ${DateFormat('M/d').format(assignment.dueDate)}',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        if (!assignment.isCompleted && !assignment.isOverdue)
          _SubmitButton(
            onPressed: () {
              // TODO: Implement submit functionality
            },
          ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final bool isCompleted;

  const _StatusIcon({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Icon(
      isCompleted ? Icons.check_circle : Icons.circle_outlined,
      color: isCompleted ? Colors.green : Colors.white54,
      size: 24,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  
  const _StatusBadge._({
    required this.text,
    required this.color,
  });
  
  factory _StatusBadge.completed() => const _StatusBadge._(
    text: 'Completed',
    color: Colors.green,
  );
  
  factory _StatusBadge.overdue() => const _StatusBadge._(
    text: 'Overdue',
    color: Colors.red,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AttachmentIndicator extends StatelessWidget {
  final int count;

  const _AttachmentIndicator({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.attach_file,
            color: Colors.white54,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '$count file${count > 1 ? 's' : ''}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SubmitButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.upload, size: 16),
        label: const Text('Submit'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        ),
      ),
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