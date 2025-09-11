import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../services/api_service_retrofit.dart';

class AssignmentCard extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final Map<String, dynamic> course;
  final ThemeService themeService;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool canEdit;
  final bool canDelete;

  const AssignmentCard({
    super.key,
    required this.assignment,
    required this.course,
    required this.themeService,
    this.onTap,
    this.onDelete,
    this.canEdit = false,
    this.canDelete = false,
  });

  @override
  State<AssignmentCard> createState() => _AssignmentCardState();
}

class _AssignmentCardState extends State<AssignmentCard> {
  late List<Map<String, dynamic>> _steps;
  final Set<String> _updatingSteps = {}; // Track which steps are being updated
  bool _isStepsExpanded = false; // Track if steps section is expanded

  @override
  void initState() {
    super.initState();
    _initializeSteps();
  }

  void _initializeSteps() {
    if (widget.assignment['steps'] != null && widget.assignment['steps'] is List) {
      _steps = List<Map<String, dynamic>>.from(
        (widget.assignment['steps'] as List).map((step) {
          if (step is Map<String, dynamic>) {
            return Map<String, dynamic>.from(step);
          }
          return <String, dynamic>{};
        }),
      );
    } else {
      _steps = [];
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'No due date';
    
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Future<void> _toggleStepCompletion(Map<String, dynamic> step, int index) async {
    final stepId = step['id'];
    if (stepId == null) return;

    // Check if this step is already being updated
    if (_updatingSteps.contains(stepId)) return;

    setState(() {
      _updatingSteps.add(stepId);
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiServiceRetrofit(authService: authService);
      
      final newIsDone = !(step['isDone'] ?? false);
      
      debugPrint('🔄 Toggling step: ${step['name']} to isDone: $newIsDone');
      
      // Update step on backend
      await apiService.updateAssignmentStep(
        widget.course['id'],
        widget.assignment['id'],
        stepId,
        {
          'isDone': newIsDone,
          'name': step['name'],
          'order': step['order'] ?? (index + 1),
        },
      );
      
      // Update local state
      setState(() {
        _steps[index]['isDone'] = newIsDone;
        _updatingSteps.remove(stepId);
      });
      
      debugPrint('✅ Step updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update step: $e');
      
      setState(() {
        _updatingSteps.remove(stepId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update step'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = AppColors.getStatusColor(widget.assignment['status']);
    final statusBgColor = AppColors.getStatusBackgroundColor(widget.assignment['status']);
    
    return Container(
      decoration: BoxDecoration(
        color: widget.themeService.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.themeService.borderColor),
      ),
      child: InkWell(
        onTap: widget.canEdit ? widget.onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Assignment header with inline status
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.assignment['title'] ?? 'Untitled Assignment',
                      style: TextStyle(
                        color: widget.themeService.textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusBgColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      (widget.assignment['status'] as String? ?? 'pending').toLowerCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Description
              if (widget.assignment['description'] != null && widget.assignment['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.assignment['description'],
                  style: TextStyle(
                    color: widget.themeService.textSecondaryColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Due date and points
              Row(
                children: [
                  // Due date
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: widget.themeService.textSecondaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Due: ${_formatDate(widget.assignment['dueDateAt'])}',
                    style: TextStyle(
                      color: widget.themeService.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Points
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: widget.themeService.textSecondaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.assignment['pointsEarned'] ?? 0}/${widget.assignment['pointsGoal'] ?? 100} pts',
                    style: TextStyle(
                      color: widget.themeService.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                  // Attachments indicator
                  if (widget.assignment['attachments'] != null && 
                      widget.assignment['attachments'] is List &&
                      (widget.assignment['attachments'] as List).isNotEmpty) ...[
                    const SizedBox(width: 20),
                    SvgPicture.asset(
                      'assets/icons/ic_attachment.svg',
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        widget.themeService.textSecondaryColor,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${(widget.assignment['attachments'] as List).length}',
                      style: TextStyle(
                        color: widget.themeService.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
              
              // Assignment Steps Section - Collapsible
              if (_steps.isNotEmpty) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isStepsExpanded = !_isStepsExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          'Assignment Steps:',
                          style: TextStyle(
                            color: widget.themeService.textSecondaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${_steps.where((s) => s['isDone'] == true).length}/${_steps.length})',
                          style: TextStyle(
                            color: widget.themeService.textTertiaryColor,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _isStepsExpanded 
                              ? Icons.keyboard_arrow_down 
                              : Icons.keyboard_arrow_right,
                          size: 20,
                          color: widget.themeService.textSecondaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                // Animated collapse/expand
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: GestureDetector(
                    onTap: () {}, // Intercept taps to prevent parent InkWell from triggering
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        ..._buildSteps(),
                      ],
                    ),
                  ),
                  crossFadeState: _isStepsExpanded 
                      ? CrossFadeState.showSecond 
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSteps() {
    // Display ALL steps without limit
    return _steps.asMap().entries.map((entry) {
      final index = entry.key;
      final step = entry.value;
      
      // Extract step text based on possible field names
      String stepText = step['name']?.toString() ?? 
                step['content']?.toString() ?? 
                step['text']?.toString() ?? 
                step['description']?.toString() ?? '';
      
      // Check if step is done
      final isDone = step['isDone'] == true;
      final stepId = step['id']?.toString();
      final isUpdating = stepId != null && _updatingSteps.contains(stepId);
      
      // Check if user is a student to disable step toggling
      final authService = Provider.of<AuthService>(context, listen: false);
      final isStudent = authService.isStudent;
      
      return InkWell(
        onTap: stepId != null && !isUpdating && !isStudent
            ? () => _toggleStepCompletion(step, index)
            : null,
        borderRadius: BorderRadius.circular(4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox with 44x44 visual area
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: isUpdating
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.themeService.textSecondaryColor,
                        ),
                      ),
                    )
                  : isDone
                      ? Icon(
                          Icons.check_circle,
                          size: 20,
                          color: widget.themeService.textColor, // White in dark mode
                        )
                      : Icon(
                          Icons.radio_button_unchecked,
                          size: 20,
                          color: widget.themeService.textTertiaryColor,
                        ),
            ),
            // Step number and text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${index + 1}. $stepText',
                  style: TextStyle(
                    color: isDone 
                        ? widget.themeService.textSecondaryColor 
                        : widget.themeService.textColor,
                    fontSize: 14,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: widget.themeService.textSecondaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}