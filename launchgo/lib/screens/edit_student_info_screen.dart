import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service_retrofit.dart';
import '../services/theme_service.dart';
import '../models/user_model.dart';

class EditStudentInfoScreen extends StatefulWidget {
  const EditStudentInfoScreen({super.key});

  @override
  State<EditStudentInfoScreen> createState() => _EditStudentInfoScreenState();
}

class _EditStudentInfoScreenState extends State<EditStudentInfoScreen> {
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
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2332),
        elevation: 0,
        title: const Text(
          'Edit Student Info',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Academic Year'),
              const SizedBox(height: 12),
              _buildYearDropdown(themeService),
              const SizedBox(height: 24),
              _buildSectionTitle('GPA'),
              const SizedBox(height: 12),
              _buildGPAField(themeService),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildYearDropdown(ThemeService themeService) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: themeService.borderColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedYear,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dropdownColor: const Color(0xFF1A2332),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
        items: _academicYears.map((year) {
          return DropdownMenuItem<String>(
            value: year,
            child: Text(year),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedYear = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select an academic year';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildGPAField(ThemeService themeService) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
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
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintText: 'Enter GPA (0.0 - 4.0)',
          hintStyle: TextStyle(
            color: Colors.grey,
            fontSize: 16,
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