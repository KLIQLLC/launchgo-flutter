import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_service_retrofit.dart';
import '../../widgets/form_submit_button.dart';
import '../../widgets/cupertino_dropdown.dart';
import '../../theme/app_colors.dart';

class CourseFormScreen extends StatefulWidget {
  final Map<String, dynamic>? course;
  
  const CourseFormScreen({super.key, this.course});

  @override
  State<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends State<CourseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _creditsController = TextEditingController();
  final _instructorController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedGrade = 'A+';
  bool _isLoading = false;
  
  final List<String> _grades = [
    'A+', 'A', 'A-',
    'B+', 'B', 'B-',
    'C+', 'C', 'C-',
    'D+', 'D', 'D-',
    'F',
    'IP',  // In Progress
    'W'    // Withdrawal
  ];

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    _nameController.text = course?['name'] ?? '';
    _codeController.text = course?['code'] ?? '';
    _creditsController.text = course?['credits']?.toString() ?? '1';
    _instructorController.text = course?['instructor'] ?? '';
    _descriptionController.text = course?['description'] ?? '';
    _selectedGrade = course?['grade'] ?? 'A+';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _creditsController.dispose();
    _instructorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiServiceRetrofit(authService: authService);
      
      final courseData = {
        'name': _nameController.text,
        'code': _codeController.text,
        'credits': int.tryParse(_creditsController.text) ?? 1,
        'instructor': _instructorController.text,
        'description': _descriptionController.text,
        'grade': _selectedGrade,
        'semesterId': authService.selectedSemesterId,
      };

      if (widget.course != null && widget.course!['id'] != null) {
        // Update existing course
        await apiService.updateCourse(widget.course!['id'], courseData);
      } else {
        // Create new course
        await apiService.createCourse(courseData);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save course: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final authService = context.watch<AuthService>();
    final selectedSemester = authService.getSelectedSemester();
    
    return Scaffold(
      backgroundColor: themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeService.backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.course != null ? 'Edit Course' : 'Add New Course',
          style: TextStyle(
            color: themeService.textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: themeService.textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course Name
                    _buildLabel('Course Name*', themeService),
                    _buildTextField(
                      controller: _nameController,
                      hintText: 'Intro to Computer Science',
                      themeService: themeService,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Course name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Course Code
                    _buildLabel('Course Code*', themeService),
                    _buildTextField(
                      controller: _codeController,
                      hintText: 'CS101',
                      themeService: themeService,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Course code is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Course Credits
                    _buildLabel('Course Credits', themeService),
                    _buildTextField(
                      controller: _creditsController,
                      hintText: '3',
                      themeService: themeService,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Instructor
                    _buildLabel('Instructor*', themeService),
                    _buildTextField(
                      controller: _instructorController,
                      hintText: 'Dr. Smith',
                      themeService: themeService,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Instructor is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Semester
                    _buildLabel('Semester*', themeService),
                    Consumer<AuthService>(
                      builder: (context, authService, child) {
                        final semesterNames = authService.semesters.map((s) => s.name).toList();
                        return CupertinoDropdown(
                          value: selectedSemester?.name,
                          items: semesterNames.isNotEmpty ? semesterNames : [],
                          hintText: semesterNames.isEmpty ? 'Loading semesters...' : 'Select semester',
                          isRequired: true,
                          onChanged: semesterNames.isEmpty ? null : (semesterName) {
                            if (semesterName != null) {
                              // Find semester by name and select it
                              final semester = authService.semesters.firstWhere(
                                (s) => s.name == semesterName,
                              );
                              authService.selectSemester(semester.id);
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a semester';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Current Grade
                    _buildLabel('Current Grade*', themeService),
                    _buildGradeDropdown(themeService),
                    const SizedBox(height: 16),

                    // Course Description
                    _buildLabel('Course Description', themeService),
                    _buildTextField(
                      controller: _descriptionController,
                      hintText: 'This course is an introduction to computer science.',
                      themeService: themeService,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Submit Button - Sticky at bottom
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeService.backgroundColor,
                border: Border(
                  top: BorderSide(
                    color: themeService.borderColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: FormSubmitButton(
                  text: widget.course != null ? 'Update Course' : 'Add Course',
                  onPressed: _saveCourse,
                  isLoading: _isLoading,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, ThemeService themeService) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: themeService.textColor,
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required ThemeService themeService,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return SizedBox(
      height: maxLines == 1 ? 42 : null,
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(
          color: themeService.inputTextColor,
          fontSize: 17,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: themeService.inputPlaceholderColor,
            fontSize: 17,
          ),
          filled: true,
          fillColor: themeService.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: themeService.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: themeService.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: ThemeService.accent),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildGradeDropdown(ThemeService themeService) {
    return CupertinoDropdown(
      value: _selectedGrade,
      items: _grades,
      hintText: 'Select grade',
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedGrade = value);
        }
      },
    );
  }
}