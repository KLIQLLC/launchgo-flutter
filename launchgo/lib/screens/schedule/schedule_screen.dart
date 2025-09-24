import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:launchgo/models/deadline_model.dart';
import 'package:launchgo/models/user_model.dart';
import 'package:launchgo/screens/schedule/edit_student_info_modal.dart';
import 'package:launchgo/services/api_service_retrofit.dart';
import 'package:launchgo/services/auth_service.dart';
import 'package:launchgo/services/permissions_service.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:launchgo/widgets/schedule/deadline_card.dart';
import 'package:launchgo/widgets/schedule/event_card.dart';
import 'package:launchgo/models/event_model.dart';
import 'package:launchgo/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

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
  final GlobalKey<_DeadlinesListState> _deadlinesListKey = GlobalKey<_DeadlinesListState>();

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
        startAt: _currentWeekStart,
        endAt: endOfWeek,
      );
      
      // API returns direct array of courses with assignments
      final courses = response
          .map((c) => DeadlineCourse.fromJson(c))
          .toList();
          
      setState(() {
        _courses = courses;
      });
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

  Future<void> _navigateToSingleEvent() async {
    final eventResult = await context.push('/new-event');
    
    // If event was created successfully, reload events
    if (eventResult == true) {
      _deadlinesListKey.currentState?.reloadEvents();
    }
  }

  Future<void> _navigateToRecurringEvent() async {
    final eventResult = await context.push('/new-recurring-event');
    
    // If events were created successfully, reload events
    if (eventResult == true) {
      _deadlinesListKey.currentState?.reloadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final authService = context.watch<AuthService>();
    final permissions = PermissionsService(authService.userInfo);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: permissions.canCreateEvents 
        ? _ExpandableFAB(
            onSingleEvent: _navigateToSingleEvent,
            onRecurrentEvent: _navigateToRecurringEvent,
          )
        : null,
      body: Column(
        children: [
          _StudentHeader(authService: authService, themeService: themeService),
          Expanded(
            child: Container(
              color: const Color(0xFF0F1419),
              child: _buildContent(themeService, authService),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await _loadDeadlines();
    // Also refresh events if the list is available
    _deadlinesListKey.currentState?.reloadEvents();
  }

  Widget _buildContent(ThemeService themeService, AuthService authService) {
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

    final permissions = PermissionsService(authService.userInfo);
    
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: ThemeService.accent,
      backgroundColor: themeService.cardColor,
      child: _DeadlinesList(
        key: _deadlinesListKey,
        assignments: _getSortedAssignments(),
        weekRangeText: _getWeekRangeText(),
        weekStart: _currentWeekStart,
        weekEnd: _currentWeekStart.add(_endOfWeekOffset),
        onPreviousWeek: () => _navigateWeek(-1),
        onNextWeek: () => _navigateWeek(1),
        themeService: themeService,
        permissions: permissions,
      ),
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
      padding: const EdgeInsets.all(12),
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

class _DeadlinesList extends StatefulWidget {
  final List<MapEntry<DeadlineCourse, DeadlineAssignment>> assignments;
  final String weekRangeText;
  final DateTime weekStart;
  final DateTime weekEnd;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final ThemeService themeService;
  final PermissionsService permissions;

  const _DeadlinesList({
    super.key,
    required this.assignments,
    required this.weekRangeText,
    required this.weekStart,
    required this.weekEnd,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.themeService,
    required this.permissions,
  });

  @override
  State<_DeadlinesList> createState() => _DeadlinesListState();
}

class _DeadlinesListState extends State<_DeadlinesList> {
  List<Event> _events = [];
  bool _isLoadingEvents = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void didUpdateWidget(_DeadlinesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload events when week dates change
    if (oldWidget.weekStart != widget.weekStart || oldWidget.weekEnd != widget.weekEnd) {
      _loadEvents();
    }
  }

  void reloadEvents() {
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      final apiService = context.read<ApiServiceRetrofit>();

      final response = await apiService.getEvents(
        startAt: widget.weekStart,
        endAt: widget.weekEnd,
      );

      final events = response.map((eventData) => Event.fromJson(eventData)).toList();
      
      setState(() {
        _events = events;
      });
    } catch (e) {
      debugPrint('Failed to load events: $e');
    } finally {
      setState(() {
        _isLoadingEvents = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildAssignmentsList(),
          const SizedBox(height: 10),
          _buildWeeklySchedule(),
          const SizedBox(height: 100),
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
        const SizedBox(height: 12),
        Row(
          children: [
            _NavigationButton(
              label: 'Previous',
              onPressed: widget.onPreviousWeek,
            ),
            Expanded(
              child: Center(
                child: Text(
                  widget.weekRangeText,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            _NavigationButton(
              label: 'Next',
              onPressed: widget.onNextWeek,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssignmentsList() {
    if (widget.assignments.isEmpty) {
      return _EmptyState(
        message: 'No deadlines for this week',
        themeService: widget.themeService,
      );
    }

    // Group assignments by course code
    Map<String, List<MapEntry<DeadlineCourse, DeadlineAssignment>>> groupedAssignments = {};
    for (final entry in widget.assignments) {
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

  Widget _buildWeeklySchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weekly Schedule',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        _buildScheduleDays(),
      ],
    );
  }

  Widget _buildScheduleDays() {
    if (_isLoadingEvents) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 48,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'No events for this week',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group events by day
    final eventsByDay = _groupEventsByDay(_events);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: eventsByDay.entries.map((dayEntry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: Text(
                  dayEntry.key,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ...dayEntry.value.map((event) {
              return Padding(
                key: ValueKey(event.id), // Add unique key based on event ID
                padding: const EdgeInsets.only(bottom: 12),
                child: EventCard(
                  key: ValueKey('event_card_${event.id}'), // Add unique key to EventCard
                  event: event,
                  onEdit: widget.permissions.canEditEvents ? () => _editEvent(event) : null,
                  onDelete: widget.permissions.canDeleteEvents ? () => _onEventDeleted(event) : null,
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }

  Map<String, List<Event>> _groupEventsByDay(List<Event> events) {
    final grouped = <String, List<Event>>{};
    final dayDates = <String, DateTime>{};
    
    for (final event in events) {
      final dayKey = _formatDayKey(event.startAt);
      if (!grouped.containsKey(dayKey)) {
        grouped[dayKey] = [];
        dayDates[dayKey] = DateTime(event.startAt.year, event.startAt.month, event.startAt.day);
      }
      grouped[dayKey]!.add(event);
    }
    
    // Sort events within each day by start time
    for (final dayEvents in grouped.values) {
      dayEvents.sort((a, b) => a.startAt.compareTo(b.startAt));
    }
    
    // Return days sorted by date (chronological order)
    final sortedEntries = grouped.entries.toList();
    sortedEntries.sort((a, b) => dayDates[a.key]!.compareTo(dayDates[b.key]!));
    
    return Map.fromEntries(sortedEntries);
  }

  String _formatDayKey(DateTime date) {
    final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    final dayName = dayNames[date.weekday % 7];
    final month = date.month;
    final day = date.day;
    
    return '$dayName $month/$day';
  }


  void _onEventDeleted(Event event) {
    // Remove the event from the local list and rebuild
    setState(() {
      _events.removeWhere((e) => e.id == event.id);
    });
  }

  Future<void> _editEvent(Event event) async {
    final result = await context.push(
      '/edit-event/${event.id}',
      extra: event,
    );
    
    // If event was updated successfully, reload events
    if (result == true) {
      _loadEvents();
    }
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
    return SizedBox(
      width: 90, // Fixed width for both buttons
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white54),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14),
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

class _ExpandableFAB extends StatefulWidget {
  final VoidCallback onSingleEvent;
  final VoidCallback onRecurrentEvent;

  const _ExpandableFAB({
    required this.onSingleEvent,
    required this.onRecurrentEvent,
  });

  @override
  State<_ExpandableFAB> createState() => _ExpandableFABState();
}

class _ExpandableFABState extends State<_ExpandableFAB>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _onOptionSelected(VoidCallback callback) {
    _toggleExpanded();
    // Add slight delay to allow animation to start before callback
    Future.delayed(const Duration(milliseconds: 100), callback);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Recurrent Event FAB
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: _isExpanded
                  ? _SubFAB(
                      icon: SvgPicture.asset(
                        'assets/icons/recurring.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Colors.white70,
                          BlendMode.srcIn,
                        ),
                      ),
                      label: 'Recurring',
                      onPressed: () => _onOptionSelected(widget.onRecurrentEvent),
                      backgroundColor: const Color(0xFF1A2332),
                      foregroundColor: Colors.white70,
                    )
                  : const SizedBox.shrink(),
            );
          },
        ),
        
        if (_isExpanded) const SizedBox(height: 16),
        
        // Single Event FAB
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: _isExpanded
                  ? _SubFAB(
                      icon: SvgPicture.asset(
                        'assets/icons/ic_calendar.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      label: 'Single',
                      onPressed: () => _onOptionSelected(widget.onSingleEvent),
                      backgroundColor: const Color(0xFF1A2332),
                      foregroundColor: Colors.white,
                    )
                  : const SizedBox.shrink(),
            );
          },
        ),
        
        if (_isExpanded) const SizedBox(height: 16),
        
        // Main FAB
        FloatingActionButton.extended(
          onPressed: _toggleExpanded,
          backgroundColor: AppColors.buttonPrimary,
          foregroundColor: const Color(0xFF1A1F2B),
          icon: Icon(_isExpanded ? Icons.close : Icons.add),
          label: Text(
            _isExpanded ? 'Close' : 'Add Event',
            style: const TextStyle(
              color: Color(0xFF1A1F2B),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SubFAB extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  const _SubFAB({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      heroTag: label, // Unique hero tag to avoid conflicts
      icon: icon,
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

