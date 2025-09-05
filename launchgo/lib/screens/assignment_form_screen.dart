import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../services/api_service_retrofit.dart';
import '../widgets/form_submit_button.dart';
import '../widgets/cupertino_dropdown.dart';

class AssignmentFormScreen extends StatefulWidget {
  final Map<String, dynamic>? course;
  final Map<String, dynamic>? assignment;
  
  const AssignmentFormScreen({
    super.key,
    this.course,
    this.assignment,
  });

  @override
  State<AssignmentFormScreen> createState() => _AssignmentFormScreenState();
}

class _AssignmentFormScreenState extends State<AssignmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pointsController = TextEditingController();
  
  DateTime? _dueDate;
  String _selectedStatus = 'pending';
  bool _isLoading = false;
  
  final List<String> _statusOptions = [
    'pending',
    'in_progress', 
    'completed',
    'overdue'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.assignment != null) {
      _titleController.text = widget.assignment!['title'] ?? '';
      _descriptionController.text = widget.assignment!['description'] ?? '';
      _pointsController.text = widget.assignment!['points']?.toString() ?? '';
      _selectedStatus = widget.assignment!['status'] ?? 'pending';
      if (widget.assignment!['dueDate'] != null) {
        _dueDate = DateTime.parse(widget.assignment!['dueDate']);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiService = context.read<ApiServiceRetrofit>();
      
      final assignmentData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'pointsGoal': int.tryParse(_pointsController.text) ?? 0,
        'pointsEarned': 0,
        'status': _selectedStatus,
        'dueDateAt': _dueDate?.toIso8601String(),
      };

      debugPrint('Creating assignment with data: $assignmentData');
      
      if (widget.course != null && widget.course!['id'] != null) {
        await apiService.createAssignment(widget.course!['id'], assignmentData);
        
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Course ID is required');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      
      if (time != null) {
        setState(() {
          _dueDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    
    return Scaffold(
      backgroundColor: themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeService.backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.assignment != null ? 'Edit Assignment' : 'Add New Assignment',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course Info
              if (widget.course != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeService.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: themeService.borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.school,
                        color: themeService.textSecondaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.course!['name'] ?? 'Unknown Course',
                        style: TextStyle(
                          color: themeService.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Assignment Title
              _buildLabel('Assignment Title*', themeService),
              _buildTextField(
                controller: _titleController,
                hintText: 'Enter assignment title',
                themeService: themeService,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Assignment title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Assignment Description
              _buildLabel('Description', themeService),
              _buildTextField(
                controller: _descriptionController,
                hintText: 'Enter assignment description',
                themeService: themeService,
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              // Points
              _buildLabel('Points', themeService),
              _buildTextField(
                controller: _pointsController,
                hintText: 'Enter points (e.g., 100)',
                themeService: themeService,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Due Date
              _buildLabel('Due Date', themeService),
              GestureDetector(
                onTap: _selectDueDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: themeService.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: themeService.borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dueDate != null
                              ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year} at ${_dueDate!.hour}:${_dueDate!.minute.toString().padLeft(2, '0')}'
                              : 'Select due date',
                          style: TextStyle(
                            color: _dueDate != null 
                                ? themeService.textColor 
                                : themeService.textSecondaryColor,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.calendar_today,
                        color: themeService.textSecondaryColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Status
              _buildLabel('Status', themeService),
              _buildStatusDropdown(themeService),
              const SizedBox(height: 32),

              // Submit Button
              FormSubmitButton(
                text: widget.assignment != null ? 'Update Assignment' : 'Create Assignment',
                onPressed: _saveAssignment,
                isLoading: _isLoading,
              ),
            ],
          ),
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
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(
        color: themeService.textColor,
        fontSize: 17,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: themeService.textSecondaryColor,
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
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildStatusDropdown(ThemeService themeService) {
    // Display the formatted version of the selected status
    final displayValue = _selectedStatus.replaceAll('_', ' ').toUpperCase();
    
    return CupertinoDropdown(
      value: displayValue,
      items: _statusOptions.map((status) => 
        status.replaceAll('_', ' ').toUpperCase()
      ).toList(),
      hintText: 'Select status',
      onChanged: (value) {
        if (value != null) {
          // Find the original status value from the formatted display text
          final index = _statusOptions.indexWhere((status) => 
            status.replaceAll('_', ' ').toUpperCase() == value
          );
          if (index != -1) {
            setState(() => _selectedStatus = _statusOptions[index]);
          }
        }
      },
    );
  }
}