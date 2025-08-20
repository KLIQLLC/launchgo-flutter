import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:provider/provider.dart';

class SemesterSelector extends StatefulWidget {
  final Function(String)? onSemesterChanged;
  final String? initialSemester;

  const SemesterSelector({
    super.key,
    this.onSemesterChanged,
    this.initialSemester,
  });

  @override
  State<SemesterSelector> createState() => _SemesterSelectorState();
}

class _SemesterSelectorState extends State<SemesterSelector> {
  late String _selectedSemester;
  final List<String> _semesters = ['Fall 2024', 'Spring 2024', 'Summer 2024'];

  @override
  void initState() {
    super.initState();
    _selectedSemester = widget.initialSemester ?? 'Fall 2024';
  }

  void _showSemesterPicker(BuildContext context, ThemeService themeService) {
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
                    initialItem: _semesters.indexOf(_selectedSemester),
                  ),
                  onSelectedItemChanged: (int index) {
                    setState(() {
                      _selectedSemester = _semesters[index];
                    });
                    widget.onSemesterChanged?.call(_selectedSemester);
                  },
                  children: _semesters.map((String semester) {
                    return Center(
                      child: Text(
                        semester,
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
      onTap: () => _showSemesterPicker(context, themeService),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: themeService.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: themeService.borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedSemester,
              style: TextStyle(
                color: themeService.textColor,
                fontSize: 14,
              ),
            ),
            Icon(
              Icons.expand_more,
              color: themeService.textColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}