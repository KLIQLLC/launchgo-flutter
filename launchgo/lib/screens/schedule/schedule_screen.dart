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
  List<DeadlineAssignment> _assignments = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _currentWeekStart = DateTime.now();
  DateTime _currentWeekEnd = DateTime.now();
  final GlobalKey<_WeeklyScheduleViewState> _weeklyViewKey = GlobalKey<_WeeklyScheduleViewState>();
  String? _lastSelectedStudentId; // Track current student to detect changes
  int _selectedSegment = 0; // 0 = Weekly Schedule, 1 = Upcoming Deadlines

  @override
  void initState() {
    super.initState();
    _initializeWeekStart();
    _loadDeadlines();
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
        debugPrint('🔄 Selected student changed to: $currentStudentId - reloading schedule data');
        _loadDeadlines();
      }
    }
  }

  void _initializeWeekStart() {
    final now = DateTime.now();
    // Get the start of the current week (Sunday at midnight)
    final weekday = now.weekday % 7; // Sunday = 0
    _currentWeekStart = DateTime(
      now.year,
      now.month,
      now.day - weekday,
      0, 0, 0, 0, 0  // Set time to midnight
    );
    // End of week is next Sunday at midnight (which captures all of Saturday)
    _currentWeekEnd = DateTime(
      _currentWeekStart.year,
      _currentWeekStart.month,
      _currentWeekStart.day + 7,
      0, 0, 0, 0, 0
    );
  }

  Future<void> _loadDeadlines() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = context.read<ApiServiceRetrofit>();

      final response = await apiService.getDeadlines(
        startAt: _currentWeekStart,
        endAt: _currentWeekEnd,
      );
      
      // API now returns direct array of assignments with embedded course info
      final assignments = response
          .map((a) => DeadlineAssignment.fromJson(a))
          .toList();
          
      setState(() {
        _assignments = assignments;
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
      if (weekOffset > 0) {
        // Move to next week - add 7 days while maintaining midnight time
        _currentWeekStart = DateTime(
          _currentWeekStart.year,
          _currentWeekStart.month,
          _currentWeekStart.day + 7,
          0, 0, 0, 0, 0
        );
      } else {
        // Move to previous week - subtract 7 days while maintaining midnight time  
        _currentWeekStart = DateTime(
          _currentWeekStart.year,
          _currentWeekStart.month,
          _currentWeekStart.day - 7,
          0, 0, 0, 0, 0
        );
      }
      // Recalculate week end - next Sunday at midnight
      _currentWeekEnd = DateTime(
        _currentWeekStart.year,
        _currentWeekStart.month,
        _currentWeekStart.day + 7,
        0, 0, 0, 0, 0
      );
    });
    _loadDeadlines();
  }

  List<DeadlineAssignment> _getSortedAssignments() {
    final assignments = List<DeadlineAssignment>.from(_assignments);
    assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return assignments;
  }

  String _getWeekRangeText() {
    final startFormat = DateFormat('MMM d');
    final endFormat = DateFormat('MMM d, yyyy');
    return '${startFormat.format(_currentWeekStart)} - ${endFormat.format(_currentWeekEnd)}';
  }

  Future<void> _navigateToSingleEvent() async {
    final eventResult = await context.push('/new-event');
    
    // If event was created successfully, reload events
    if (eventResult == true) {
      _weeklyViewKey.currentState?.reloadEvents();
    }
  }

  Future<void> _navigateToRecurringEvent() async {
    final eventResult = await context.push('/new-recurring-event');
    
    // If events were created successfully, reload events
    if (eventResult == true) {
      _weeklyViewKey.currentState?.reloadEvents();
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
              child: Column(
                children: [
                  _WeekNavigator(
                    key: const ValueKey('week_navigator'),
                    weekRangeText: _getWeekRangeText(),
                    onPreviousWeek: () => _navigateWeek(-1),
                    onNextWeek: () => _navigateWeek(1),
                  ),
                  Expanded(
                    child: _buildSegmentedContent(themeService, authService),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await _loadDeadlines();
    // Also refresh events if the weekly view is available
    if (_selectedSegment == 0) {
      _weeklyViewKey.currentState?.reloadEvents();
    }
  }

  Widget _buildSegmentedContent(ThemeService themeService, AuthService authService) {
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
    
    return Column(
      children: [
        _SegmentedControl(
          selectedIndex: _selectedSegment,
          onSegmentChanged: (index) {
            setState(() {
              _selectedSegment = index;
            });
          },
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: ThemeService.accent,
            backgroundColor: themeService.cardColor,
            child: _selectedSegment == 0
                ? _WeeklyScheduleView(
                    key: _weeklyViewKey,
                    weekStart: _currentWeekStart,
                    weekEnd: _currentWeekEnd,
                    themeService: themeService,
                    permissions: permissions,
                  )
                : _UpcomingDeadlinesView(
                    assignments: _getSortedAssignments(),
                    themeService: themeService,
                  ),
          ),
        ),
      ],
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSegmentChanged;

  const _SegmentedControl({
    required this.selectedIndex,
    required this.onSegmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1A2332),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              text: 'Weekly Schedule',
              isSelected: selectedIndex == 0,
              onTap: () => onSegmentChanged(0),
              isFirst: true,
            ),
          ),
          Expanded(
            child: _SegmentButton(
              text: 'Upcoming Deadlines',
              isSelected: selectedIndex == 1,
              onTap: () => onSegmentChanged(1),
              isFirst: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isFirst;

  const _SegmentButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected 
              ? const Color(0xFF0F1419) // Dark background for selected
              : Colors.transparent,
          border: isSelected
              ? Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 1)
              : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected 
                ? Colors.white 
                : Colors.grey[500], // Dimmed text for unselected
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _WeekNavigator extends StatelessWidget {
  final String weekRangeText;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  const _WeekNavigator({
    super.key,
    required this.weekRangeText,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _NavigationButton(
            icon: Icons.arrow_back_ios_new,
            onPressed: onPreviousWeek,
          ),
          Expanded(
            child: Center(
              child: Text(
                weekRangeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _NavigationButton(
            icon: Icons.arrow_forward_ios,
            onPressed: onNextWeek,
          ),
        ],
      ),
    );
  }
}

class _WeeklyScheduleView extends StatefulWidget {
  final DateTime weekStart;
  final DateTime weekEnd;
  final ThemeService themeService;
  final PermissionsService permissions;

  const _WeeklyScheduleView({
    super.key,
    required this.weekStart,
    required this.weekEnd,
    required this.themeService,
    required this.permissions,
  });

  @override
  State<_WeeklyScheduleView> createState() => _WeeklyScheduleViewState();
}

class _WeeklyScheduleViewState extends State<_WeeklyScheduleView> {
  List<Event> _events = [];
  bool _isLoadingEvents = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void didUpdateWidget(_WeeklyScheduleView oldWidget) {
    super.didUpdateWidget(oldWidget);
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
            mainAxisAlignment: MainAxisAlignment.center,
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

    final eventsByDay = _groupEventsByDay(_events);
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...eventsByDay.entries.map((dayEntry) {
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
                    key: ValueKey(event.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EventCard(
                      key: ValueKey('event_card_${event.id}'),
                      event: event,
                      onEdit: (widget.permissions.canEditEvents && event.type.toLowerCase() != 'assignment') ? () => _editEvent(event) : null,
                      onDelete: (widget.permissions.canDeleteEvents && event.type.toLowerCase() != 'assignment') ? () => _onEventDeleted(event) : null,
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ],
            );
          }),
          const SizedBox(height: 100),
        ],
      ),
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
    
    for (final dayEvents in grouped.values) {
      dayEvents.sort((a, b) => a.startAt.compareTo(b.startAt));
    }
    
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
    setState(() {
      _events.removeWhere((e) => e.id == event.id);
    });
  }

  Future<void> _editEvent(Event event) async {
    final result = await context.push(
      '/edit-event/${event.id}',
      extra: event,
    );
    
    if (result == true) {
      _loadEvents();
    }
  }
}

class _UpcomingDeadlinesView extends StatelessWidget {
  final List<DeadlineAssignment> assignments;
  final ThemeService themeService;

  const _UpcomingDeadlinesView({
    required this.assignments,
    required this.themeService,
  });

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'No deadlines for this week',
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

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...assignments.map((assignment) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    assignment.course?.code ?? 'Unknown Course',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DeadlineCard(
                    assignment: assignment,
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 100),
        ],
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
    return gpaValue != null ? gpaValue.toStringAsFixed(1) : 'N/A';
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



class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _NavigationButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50, // Reduced width for icon buttons
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white54),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Padding(
          padding: icon == Icons.arrow_back_ios_new 
              ? const EdgeInsets.only(right: 4) 
              : icon == Icons.arrow_forward_ios
                  ? const EdgeInsets.only(left: 4)
                  : EdgeInsets.zero,
          child: Icon(
            icon,
            size: 18,
          ),
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
        // Recurrent Event FAB - DISABLED FOR NOW
        // AnimatedBuilder(
        //   animation: _scaleAnimation,
        //   builder: (context, child) {
        //     return Transform.scale(
        //       scale: _scaleAnimation.value,
        //       child: _isExpanded
        //           ? _SubFAB(
        //               icon: SvgPicture.asset(
        //                 'assets/icons/recurring.svg',
        //                 width: 20,
        //                 height: 20,
        //                 colorFilter: const ColorFilter.mode(
        //                   Colors.white70,
        //                   BlendMode.srcIn,
        //                 ),
        //               ),
        //               label: 'Recurring',
        //               onPressed: () => _onOptionSelected(widget.onRecurrentEvent),
        //               backgroundColor: const Color(0xFF1A2332),
        //               foregroundColor: Colors.white70,
        //             )
        //           : const SizedBox.shrink(),
        //     );
        //   },
        // ),
        
        // if (_isExpanded) const SizedBox(height: 16),
        
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

