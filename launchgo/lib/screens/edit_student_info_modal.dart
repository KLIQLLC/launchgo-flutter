import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service_retrofit.dart';
import '../services/theme_service.dart';
import '../models/user_model.dart';

class EditStudentInfoModal extends StatefulWidget {
  const EditStudentInfoModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const EditStudentInfoModal(),
    );
  }

  @override
  State<EditStudentInfoModal> createState() => _EditStudentInfoModalState();
}

class _EditStudentInfoModalState extends State<EditStudentInfoModal> {
  final _formKey = GlobalKey<FormState>();
  final _gpaController = TextEditingController();
  String? _selectedYear;
  bool _isLoading = false;
  
  final List<String> _academicYears = [
    'Freshman',
    'Sophomore',
    'Junior',
    'Senior',
    'Graduate',
  ];

  @override
  void initState() {
    super.initState();
    _initializeValues();
  }

  void _initializeValues() {
    final authService = context.read<AuthService>();
    final student = authService.getSelectedStudent() ?? authService.userInfo;
    
    String? academicYear;
    String? gpa;
    
    if (student is Student) {
      academicYear = student.academicYear;
      gpa = student.gpa?.toStringAsFixed(1);
    } else if (student is UserModel && student.students.isNotEmpty) {
      final firstStudent = student.students.first;
      academicYear = firstStudent.academicYear;
      gpa = firstStudent.gpa?.toStringAsFixed(1);
    }
    
    // Normalize the academic year to match our dropdown options
    if (academicYear != null) {
      final normalized = _normalizeAcademicYear(academicYear);
      _selectedYear = _academicYears.contains(normalized) ? normalized : 'Sophomore';
    } else {
      _selectedYear = 'Sophomore';
    }
    
    _gpaController.text = gpa ?? '2.4';
  }
  
  String _normalizeAcademicYear(String year) {
    // Convert to lowercase for comparison, then capitalize first letter
    final lower = year.toLowerCase();
    if (lower.isEmpty) return 'Sophomore';
    return lower[0].toUpperCase() + lower.substring(1);
  }

  @override
  void dispose() {
    _gpaController.dispose();
    super.dispose();
  }

  String? _getStudentId() {
    final authService = context.read<AuthService>();
    final selectedStudent = authService.getSelectedStudent();
    
    if (selectedStudent != null) {
      return selectedStudent.id;
    }
    
    // If user is a student (not a mentor)
    if (authService.userInfo?.role == UserRole.student) {
      return authService.userInfo?.id;
    }
    
    // If user is a mentor with students
    if (authService.userInfo?.students.isNotEmpty == true) {
      return authService.userInfo!.students.first.id;
    }
    
    return null;
  }

  Future<void> _saveChanges() async {
    if (_selectedYear == null || _selectedYear!.isEmpty) {
      _showSnackBar('Please select an academic year', isError: true);
      return;
    }
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final studentId = _getStudentId();
    if (studentId == null) {
      _showSnackBar('Unable to identify student', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = context.read<ApiServiceRetrofit>();
      final gpaValue = double.tryParse(_gpaController.text);
      
      if (gpaValue == null) {
        _showSnackBar('Invalid GPA value', isError: true);
        return;
      }

      final updateData = {
        'academicYear': _selectedYear?.toLowerCase(),
        'gpa': gpaValue,
      };

      await apiService.updateStudentInfo(studentId, updateData);
      
      // Update local user info
      if (mounted) {
        final authService = context.read<AuthService>();
        await authService.loadUserInfo();
        
        _showSnackBar('Student information updated successfully');
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      debugPrint('Error updating student info: $e');
      _showSnackBar('Failed to update student information', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2332),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Text(
                  'Edit Student Info',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                else
                  TextButton(
                    onPressed: _saveChanges,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A3441), height: 1),
          // Form content
          Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Please select the academic year and enter the GPA for the student.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Select academic year:'),
                  const SizedBox(height: 8),
                  _buildYearDropdown(themeService),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Enter GPA:'),
                  const SizedBox(height: 8),
                  _buildGPAField(themeService),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildYearDropdown(ThemeService themeService) {
    return GestureDetector(
      onTap: () {
        _showCupertinoPicker();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1419),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: themeService.borderColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedYear ?? 'Select year',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_down,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showCupertinoPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      CupertinoButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
                    itemExtent: 32.0,
                    scrollController: FixedExtentScrollController(
                      initialItem: _academicYears.indexOf(_selectedYear ?? 'Sophomore'),
                    ),
                    onSelectedItemChanged: (int selectedItem) {
                      setState(() {
                        _selectedYear = _academicYears[selectedItem];
                      });
                    },
                    children: _academicYears.map((String year) {
                      return Center(
                        child: Text(
                          year,
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGPAField(ThemeService themeService) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1419),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: themeService.borderColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: _gpaController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          hintText: 'Enter GPA (0.0 - 4.0)',
          hintStyle: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a GPA value';
          }
          
          final gpa = double.tryParse(value);
          if (gpa == null) {
            return 'Please enter a valid number';
          }
          
          if (gpa < 0.0 || gpa > 4.0) {
            return 'GPA must be between 0.0 and 4.0';
          }
          
          return null;
        },
      ),
    );
  }
}