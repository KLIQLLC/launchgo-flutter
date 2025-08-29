import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../features/documents/domain/entities/document_entity.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../widgets/cupertino_dropdown.dart';

enum DocumentScreenMode {
  create,
  edit,
}

class DocumentFormScreen extends StatefulWidget {
  final DocumentScreenMode mode;
  final DocumentEntity? document;
  
  const DocumentFormScreen({
    super.key,
    this.mode = DocumentScreenMode.create,
    this.document,
  });

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _semesterController;
  String? _selectedCourse;
  bool _isSubmitting = false;

  final List<String> _courses = ['Select course (optional)', 'CODE11', 'CODE12', 'CODE13'];
  final List<String> _categories = [
    'Notes',
    'Assignment',
    'Study Guide'
  ];
  
  bool get isEditMode => widget.mode == DocumentScreenMode.edit;

  @override
  void initState() {
    super.initState();
    
    if (isEditMode && widget.document != null) {
      // Initialize with existing document data
      _nameController = TextEditingController(text: widget.document!.name);
      
      // Map category from API format to display format
      String initialCategory = 'Notes';
      switch (widget.document!.category) {
        case 'notes':
          initialCategory = 'Notes';
          break;
        case 'assignment':
          initialCategory = 'Assignment';
          break;
        case 'study-guide':
          initialCategory = 'Study Guide';
          break;
      }
      _categoryController = TextEditingController(text: initialCategory);
      _semesterController = TextEditingController();
      
      // Map courseId to course name
      if (widget.document!.courseId != null) {
        final courseId = widget.document!.courseId!.toUpperCase();
        if (_courses.contains(courseId)) {
          _selectedCourse = courseId;
        }
      }
    } else {
      // Create mode - default values
      _nameController = TextEditingController();
      _categoryController = TextEditingController(text: 'Notes');
      _semesterController = TextEditingController();
      _selectedCourse = null;
    }
    
    // Load semesters when form opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      if (authService.semesters.isEmpty) {
        authService.loadSemesters().then((_) {
          _setSemesterValue(authService);
        });
      } else {
        _setSemesterValue(authService);
      }
    });
  }

  void _setSemesterValue(AuthService authService) {
    if (isEditMode && widget.document != null && widget.document!.semesterId != null) {
      // In edit mode, find semester by document's semesterId
      try {
        final semester = authService.semesters.firstWhere(
          (s) => s.id == widget.document!.semesterId,
        );
        setState(() {
          _semesterController.text = semester.name;
        });
        debugPrint('Set semester for edit mode: ${semester.name} (${semester.id})');
      } catch (e) {
        debugPrint('Warning: Document semester not found: ${widget.document!.semesterId}');
        // Leave semester unselected if not found
      }
    } else {
      // In create mode, use currently selected semester as initial value
      final selectedSemester = authService.getSelectedSemester();
      setState(() {
        _semesterController.text = selectedSemester?.name ?? '';
      });
      debugPrint('Set initial semester for create mode: ${selectedSemester?.name ?? 'none'}');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  Future<void> _submitDocument() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService: authService);
      
      // Find semester ID from name
      final selectedSemesterName = _semesterController.text.trim();
      String? semesterId;
      
      try {
        final semester = authService.semesters.firstWhere(
          (s) => s.name == selectedSemesterName,
        );
        semesterId = semester.id;
      } catch (e) {
        // Semester not found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a valid semester'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }
      
      final documentData = {
        'name': _nameController.text.trim(),
        'category': _categoryController.text.trim().toLowerCase().replaceAll(' ', '-'), // Category in lowercase with dashes
        'semesterId': semesterId,
        'courseId': (_selectedCourse != null && _selectedCourse != 'Select course (optional)') 
            ? _selectedCourse!.toLowerCase() 
            : '', // Course as courseId, empty string if not selected
      };

      if (isEditMode) {
        await apiService.updateDocument(widget.document!.id, documentData);
      } else {
        await apiService.createDocument(documentData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditMode 
                ? 'Document updated successfully' 
                : 'Document created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditMode 
                ? 'Failed to update document: ${e.toString()}'
                : 'Failed to create document: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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
        leading: IconButton(
          icon: Icon(Icons.close, color: themeService.textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditMode ? 'Edit Document' : 'Create New Document',
          style: TextStyle(
            color: themeService.textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Document Name Field
                Text(
                  'Document Name',
                  style: TextStyle(
                    color: themeService.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: themeService.textColor),
                  decoration: InputDecoration(
                    hintText: 'Enter document name',
                    hintStyle: TextStyle(color: themeService.textTertiaryColor),
                    filled: true,
                    fillColor: themeService.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: themeService.borderColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: themeService.borderColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: ThemeService.accent,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a document name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Category Field
                Text(
                  'Category',
                  style: TextStyle(
                    color: themeService.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoDropdown(
                  value: _categoryController.text.isEmpty ? null : _categoryController.text,
                  items: _categories,
                  hintText: 'Select category',
                  isRequired: true,
                  onChanged: (value) {
                    setState(() {
                      _categoryController.text = value ?? '';
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Semester Field
                Text(
                  'Semester',
                  style: TextStyle(
                    color: themeService.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Consumer<AuthService>(
                  builder: (context, authService, child) {
                    final semesterNames = authService.semesters.map((s) => s.name).toList();
                    return CupertinoDropdown(
                      value: _semesterController.text.isEmpty ? null : _semesterController.text,
                      items: semesterNames.isNotEmpty ? semesterNames : [],
                      hintText: semesterNames.isEmpty ? 'Loading semesters...' : 'Select semester',
                      isRequired: true,
                      onChanged: semesterNames.isEmpty ? null : (value) {
                        setState(() {
                          _semesterController.text = value ?? '';
                        });
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
                const SizedBox(height: 24),

                // Course Field (Optional)
                Text(
                  'Course (Optional)',
                  style: TextStyle(
                    color: themeService.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoDropdown(
                  value: _selectedCourse,
                  items: _courses,
                  hintText: 'Select course (optional)',
                  onChanged: (value) {
                    setState(() {
                      _selectedCourse = value;
                    });
                  },
                ),
                const SizedBox(height: 32),

                // Submit Button (Alternative to top bar Save)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitDocument,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1A1F2B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : Text(
                            isEditMode ? 'Update Document' : 'Create Document',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}