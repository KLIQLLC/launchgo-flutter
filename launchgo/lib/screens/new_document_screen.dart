import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';

class NewDocumentScreen extends StatefulWidget {
  const NewDocumentScreen({super.key});

  @override
  State<NewDocumentScreen> createState() => _NewDocumentScreenState();
}

class _NewDocumentScreenState extends State<NewDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Notes'); // Preselect Notes
  String? _selectedCourse;
  bool _isSubmitting = false;

  final List<String> _courses = ['Select course (optional)', 'CODE11', 'CODE12', 'CODE13'];
  final List<String> _categories = [
    'Notes',
    'Assignment',
    'Study Guide'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
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
      
      final documentData = {
        'name': _nameController.text.trim(),
        'type': '', // Empty string for type
        'category': _categoryController.text.trim().toLowerCase(), // Category in lowercase
        'tag': (_selectedCourse != null && _selectedCourse != 'Select course (optional)') 
            ? _selectedCourse!.toLowerCase() 
            : '', // Course as tag, empty string if not selected
      };

      await apiService.createDocument(documentData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create document: ${e.toString()}'),
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
          'Create New Document',
          style: TextStyle(
            color: themeService.textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitDocument,
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ThemeService.accent,
                      ),
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: ThemeService.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
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
                DropdownButtonFormField<String>(
                  value: _categoryController.text.isEmpty ? null : _categoryController.text,
                  style: TextStyle(color: themeService.textColor),
                  dropdownColor: themeService.cardColor,
                  decoration: InputDecoration(
                    hintText: 'Select category',
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
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
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
                DropdownButtonFormField<String>(
                  value: _selectedCourse,
                  style: TextStyle(color: themeService.textColor),
                  dropdownColor: themeService.cardColor,
                  decoration: InputDecoration(
                    hintText: 'Select course (optional)',
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
                  ),
                  items: _courses.map((course) {
                    return DropdownMenuItem<String>(
                      value: course,
                      child: Text(course),
                    );
                  }).toList(),
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
                        : const Text(
                            'Create Document',
                            style: TextStyle(
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