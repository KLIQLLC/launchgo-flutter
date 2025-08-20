import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:provider/provider.dart';

class CourseFilterSelector extends StatefulWidget {
  final Function(String)? onCourseChanged;
  final String? initialCourse;
  final List<String>? courses;

  const CourseFilterSelector({
    super.key,
    this.onCourseChanged,
    this.initialCourse,
    this.courses,
  });

  @override
  State<CourseFilterSelector> createState() => _CourseFilterSelectorState();
}

class _CourseFilterSelectorState extends State<CourseFilterSelector> {
  late String _selectedCourse;
  late List<String> _courses;

  @override
  void initState() {
    super.initState();
    _courses = widget.courses ?? ['All', 'CODE11', 'CODE12', 'CODE13'];
    _selectedCourse = widget.initialCourse ?? 'All';
  }

  void _showCoursePicker(BuildContext context, ThemeService themeService) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: themeService.backgroundColor,
          child: Column(
            children: [
              // Header with Done button
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: themeService.cardColor,
                  border: Border(
                    bottom: BorderSide(
                      color: themeService.borderColor,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: themeService.textSecondaryColor,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: ThemeService.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Picker
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: themeService.backgroundColor,
                  itemExtent: 32,
                  scrollController: FixedExtentScrollController(
                    initialItem: _courses.indexOf(_selectedCourse),
                  ),
                  onSelectedItemChanged: (int index) {
                    setState(() {
                      _selectedCourse = _courses[index];
                    });
                    widget.onCourseChanged?.call(_selectedCourse);
                  },
                  children: _courses.map((String course) {
                    return Center(
                      child: Text(
                        course,
                        style: TextStyle(
                          color: themeService.textColor,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    
    return GestureDetector(
      onTap: () => _showCoursePicker(context, themeService),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: themeService.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: themeService.borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedCourse,
              style: TextStyle(
                color: themeService.textColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.expand_more,
              color: themeService.textColor,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}