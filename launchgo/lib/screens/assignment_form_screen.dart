import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../services/api_service_retrofit.dart';
import '../widgets/form_submit_button.dart';
import '../widgets/cupertino_dropdown.dart';
import '../theme/app_colors.dart';

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
  final _earnedPointsController = TextEditingController(text: '0');
  final _newStepController = TextEditingController();
  final List<TextEditingController> _stepControllers = [];
  final List<Map<String, dynamic>?> _originalStepData = []; // Track original step data with IDs
  final List<PlatformFile> _selectedFiles = [];
  
  DateTime? _dueDate;
  String _selectedStatus = 'pending';
  bool _isLoading = false;
  
  final List<String> _statusOptions = [
    'pending',
    'completed',
    'overdue'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.assignment != null) {
      _titleController.text = widget.assignment!['title'] ?? '';
      _descriptionController.text = widget.assignment!['description'] ?? '';
      _pointsController.text = widget.assignment!['pointsGoal']?.toString() ?? '';
      _earnedPointsController.text = widget.assignment!['pointsEarned']?.toString() ?? '0';
      _selectedStatus = widget.assignment!['status'] ?? 'pending';
      if (widget.assignment!['dueDateAt'] != null) {
        _dueDate = DateTime.parse(widget.assignment!['dueDateAt']);
      }
      
      // Load existing steps - Enhanced debugging
      debugPrint('🔍 ===== ASSIGNMENT LOADING DEBUG =====');
      debugPrint('🔍 Full assignment data: ${widget.assignment}');
      debugPrint('🔍 Assignment keys: ${widget.assignment!.keys.toList()}');
      debugPrint('🔍 Steps data in assignment: ${widget.assignment!['steps']}');
      debugPrint('🔍 Steps data type: ${widget.assignment!['steps'].runtimeType}');
      
      if (widget.assignment!['steps'] != null) {
        final steps = widget.assignment!['steps'];
        debugPrint('🔍 Raw steps: $steps');
        debugPrint('🔍 Steps type: ${steps.runtimeType}');
        
        if (steps is List) {
          debugPrint('🔍 Found ${steps.length} steps to load');
          
          for (int i = 0; i < steps.length; i++) {
            final step = steps[i];
            debugPrint('🔍 Step $i: $step (type: ${step.runtimeType})');
            
            // Handle different possible step data structures
            String? content;
            if (step is Map<String, dynamic>) {
              debugPrint('🔍 Step $i is Map - keys: ${step.keys.toList()}');
              // Try different field names that might contain the step content
              content = step['content']?.toString() ?? 
                       step['text']?.toString() ?? 
                       step['description']?.toString() ?? 
                       step['name']?.toString(); // Backend uses 'name' field
            } else if (step is String) {
              debugPrint('🔍 Step $i is String: "$step"');
              content = step;
            } else {
              debugPrint('⚠️ Step $i is unknown type: ${step.runtimeType}');
            }
            
            if (content != null && content.isNotEmpty) {
              final controller = TextEditingController(text: content);
              _stepControllers.add(controller);
              // Store the original step data with ID for updates
              _originalStepData.add(step is Map<String, dynamic> ? Map<String, dynamic>.from(step) : null);
              debugPrint('✅ Added step controller $i with content: "$content"');
            } else {
              debugPrint('⚠️ Step $i has no valid content: content="$content"');
            }
          }
        } else {
          debugPrint('⚠️ Steps is not a List, it is: ${steps.runtimeType}');
        }
      } else {
        debugPrint('⚠️ No steps data found in assignment');
      }
      
      debugPrint('🔍 Total step controllers loaded: ${_stepControllers.length}');
      debugPrint('🔍 ===== END ASSIGNMENT LOADING DEBUG =====');
      
      // Note: File attachments can't be loaded as PlatformFiles in edit mode
      // They would need to be downloaded from storage, which is beyond current scope
      // The UI will show "Attach file" button allowing replacement
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    _earnedPointsController.dispose();
    _newStepController.dispose();
    for (var controller in _stepControllers) {
      controller.dispose();
    }
    _originalStepData.clear();
    super.dispose();
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiServiceRetrofit(authService: authService);
      
      // Prepare steps data - use 'name' field to match backend API
      // Include IDs for existing steps to enable proper updates/deletions
      final stepsData = _stepControllers.asMap().entries.map((entry) {
        final index = entry.key;
        final controller = entry.value;
        final stepText = controller.text.trim();
        
        if (stepText.isEmpty) return null;
        
        final stepData = <String, dynamic>{
          'name': stepText, // Backend expects 'name' field
          'order': index + 1,
          'isDone': false, // Required field - default to false for new/updated steps
        };
        
        // Include ID and other fields for existing steps so backend can update/delete properly
        if (index < _originalStepData.length && _originalStepData[index] != null) {
          final originalStep = _originalStepData[index]!;
          stepData['id'] = originalStep['id'];
          // Preserve the original isDone status
          stepData['isDone'] = originalStep['isDone'] ?? false;
          // Include other required fields if they exist
          if (originalStep['assignmentId'] != null) stepData['assignmentId'] = originalStep['assignmentId'];
          if (originalStep['courseId'] != null) stepData['courseId'] = originalStep['courseId'];
          if (originalStep['ownerId'] != null) stepData['ownerId'] = originalStep['ownerId'];
          debugPrint('📝 Including existing step ID: ${originalStep['id']} for "$stepText" (isDone: ${stepData['isDone']})');
        } else {
          debugPrint('📝 New step (no ID): "$stepText" (isDone: false)');
        }
        
        return stepData;
      }).where((step) => step != null).cast<Map<String, dynamic>>().toList();
      
      debugPrint('📝 === STEPS UPDATE DEBUG ===');
      debugPrint('📝 Original assignment had ${widget.assignment?['steps']?.length ?? 0} steps');
      debugPrint('📝 Current step controllers count: ${_stepControllers.length}');
      debugPrint('📝 Original step data count: ${_originalStepData.length}');
      
      for (int i = 0; i < _stepControllers.length; i++) {
        debugPrint('📝 Step $i name: "${_stepControllers[i].text}"');
        if (i < _originalStepData.length) {
          debugPrint('📝   - Original data: ${_originalStepData[i]}');
        } else {
          debugPrint('📝   - No original data (new step)');
        }
      }
      
      debugPrint('📝 Steps data being sent to API: $stepsData');
      debugPrint('📝 Number of steps being sent: ${stepsData.length}');
      debugPrint('📝 === END STEPS DEBUG ===');

      // Prepare attachments data (metadata only for now)
      final attachmentsData = _selectedFiles.map((file) => {
        'name': file.name,
        'size': file.size,
        'mimeType': _getMimeType(file.extension),
        // TODO: Implement file upload to storage service
        // For now, we'll send file metadata only
      }).toList();

      // Use selected date or default to 7 days from now if not set
      final dueDateToUse = _dueDate ?? DateTime.now().add(const Duration(days: 7));
      
      final assignmentData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'pointsGoal': int.tryParse(_pointsController.text) ?? 0,
        'pointsEarned': int.tryParse(_earnedPointsController.text) ?? 0,
        'status': _selectedStatus,
        'dueDateAt': '${dueDateToUse.year}-${dueDateToUse.month.toString().padLeft(2, '0')}-${dueDateToUse.day.toString().padLeft(2, '0')}',
        'steps': stepsData,
        'attachments': attachmentsData,
      };

      debugPrint('📋 Complete assignment data being sent: $assignmentData');
      
      if (widget.assignment != null) {
        // Update existing assignment
        debugPrint('🔄 Updating assignment with data: $assignmentData');
        debugPrint('🔄 Course ID: ${widget.course!['id']}');
        debugPrint('🔄 Assignment ID: ${widget.assignment!['id']}');
        
        final result = await apiService.updateAssignment(
          widget.course!['id'], 
          widget.assignment!['id'], 
          assignmentData
        );
        
        debugPrint('✅ Update result: $result');
      } else {
        // Create new assignment
        debugPrint('🆕 Creating assignment with data: $assignmentData');
        final result = await apiService.createAssignment(widget.course!['id'], assignmentData);
        debugPrint('✅ Create result: $result');
      }
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save assignment: $e'),
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

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
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
          widget.assignment != null ? 'Edit Assignment' : 'Add Assignment',
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
              // Assignment Title
              _buildLabel('Assignment Title*', themeService),
              _buildTextField(
                controller: _titleController,
                hintText: 'Programming Assignment 1',
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
                hintText: 'Assignment description...',
                themeService: themeService,
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              // Due Date and Points in the same row
              Row(
                children: [
                  // Due Date (takes 50% of width)
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Due Date', themeService),
                        GestureDetector(
                          onTap: _selectDueDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: themeService.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: themeService.borderColor),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _dueDate != null
                                        ? '${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.day.toString().padLeft(2, '0')}/${_dueDate!.year}'
                                        : 'mm/dd/yyyy',
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Points (takes 50% of width)
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Points', themeService),
                        _buildTextField(
                          controller: _pointsController,
                          hintText: '100',
                          themeService: themeService,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status and Earned Points in the same row
              Row(
                children: [
                  // Status (takes 50% of width)
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Status', themeService),
                        _buildStatusDropdown(themeService),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Earned Points (takes 50% of width)
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Earned Points (optional)', themeService),
                        _buildTextField(
                          controller: _earnedPointsController,
                          hintText: '0',
                          themeService: themeService,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Attach Documents Section
              _buildLabel('Attach Documents', themeService),
              _buildDocumentUploadArea(themeService),
              const SizedBox(height: 24),

              // Assignment Steps Section
              _buildLabel('Assignment Steps', themeService),
              _buildAssignmentSteps(themeService),
              const SizedBox(height: 32),

              // Submit Button
              FormSubmitButton(
                text: widget.assignment != null ? 'Update Assignment' : 'Add Assignment',
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
          fontSize: 16,
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
        fontSize: 16,
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
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: themeService.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: themeService.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ThemeService.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Widget _buildStatusDropdown(ThemeService themeService) {
    return CupertinoDropdown(
      value: _capitalizeFirst(_selectedStatus),
      items: _statusOptions.map((status) => _capitalizeFirst(status)).toList(),
      hintText: 'Select status',
      onChanged: (value) {
        if (value != null) {
          // Find the original status value from the display text
          final index = _statusOptions.indexWhere((status) => 
            _capitalizeFirst(status) == value
          );
          if (index != -1) {
            setState(() => _selectedStatus = _statusOptions[index]);
          }
        }
      },
    );
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'gif', 'txt'],
        withData: true,
      );

      if (result != null) {
        // Check file size limit (5MB)
        final file = result.files.first;
        if (file.size > 5 * 1024 * 1024) { // 5MB in bytes
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File "${file.name}" exceeds 5MB limit'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedFiles.clear(); // Clear existing file
          _selectedFiles.add(file); // Add new file
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File attached: ${file.name}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getMimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Widget _buildDocumentUploadArea(ThemeService themeService) {
    return Column(
      children: [
        // File picker button
        GestureDetector(
          onTap: _pickFiles,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeService.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeService.borderColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: themeService.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.attach_file,
                    size: 20,
                    color: themeService.textSecondaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFiles.isEmpty ? 'Attach file' : 'Replace file',
                        style: TextStyle(
                          color: themeService.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PDF, Word, Images (Max 5MB)',
                        style: TextStyle(
                          color: themeService.textSecondaryColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _selectedFiles.isEmpty ? Icons.chevron_right : Icons.refresh,
                  color: themeService.textSecondaryColor,
                ),
              ],
            ),
          ),
        ),
        // Selected files list
        if (_selectedFiles.isNotEmpty) ...[ 
          const SizedBox(height: 12),
          for (int i = 0; i < _selectedFiles.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: themeService.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: themeService.borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    _getFileIcon(_selectedFiles[i].extension),
                    size: 20,
                    color: themeService.textSecondaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFiles[i].name,
                          style: TextStyle(
                            color: themeService.textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatFileSize(_selectedFiles[i].size),
                          style: TextStyle(
                            color: themeService.textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeFile(i),
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: themeService.textSecondaryColor,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildAssignmentSteps(ThemeService themeService) {
    debugPrint('🎨 Building assignment steps UI - ${_stepControllers.length} controllers');
    return Column(
      children: [
        // Existing steps
        ..._stepControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    style: TextStyle(
                      color: themeService.textColor,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      prefixText: '${index + 1}. ',
                      prefixStyle: TextStyle(
                        color: themeService.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: themeService.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeService.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeService.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ThemeService.accent),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _stepControllers[index].dispose();
                      _stepControllers.removeAt(index);
                      // Also remove from original data tracking
                      if (index < _originalStepData.length) {
                        _originalStepData.removeAt(index);
                      }
                    });
                  },
                  icon: Icon(
                    Icons.close,
                    color: themeService.textSecondaryColor,
                  ),
                ),
              ],
            ),
          );
        }),
        // Add new step row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newStepController,
                style: TextStyle(
                  color: themeService.textColor,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Add a step...',
                  hintStyle: TextStyle(
                    color: themeService.textSecondaryColor,
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: themeService.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: themeService.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: themeService.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ThemeService.accent),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _stepControllers.length < 10 ? () {
                if (_newStepController.text.trim().isNotEmpty) {
                  setState(() {
                    final newController = TextEditingController(text: _newStepController.text);
                    _stepControllers.add(newController);
                    // Add null for new steps (no original data)
                    _originalStepData.add(null);
                    _newStepController.clear();
                  });
                }
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _stepControllers.length < 10 
                    ? themeService.backgroundColor 
                    : themeService.backgroundColor.withValues(alpha: 0.5),
                foregroundColor: _stepControllers.length < 10 
                    ? themeService.textColor 
                    : themeService.textColor.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _stepControllers.length < 10 
                        ? themeService.borderColor 
                        : themeService.borderColor.withValues(alpha: 0.5)
                  ),
                ),
              ),
              child: Text(
                _stepControllers.length < 10 
                    ? 'Add Step (${_stepControllers.length}/10)' 
                    : 'Max steps reached',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _stepControllers.length < 10 
                      ? themeService.textColor 
                      : themeService.textColor.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}