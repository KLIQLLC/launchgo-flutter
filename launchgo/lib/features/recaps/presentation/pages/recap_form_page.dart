import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../../../models/recap_model.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/theme_service.dart';
import '../../../../widgets/cupertino_dropdown.dart';
import '../bloc/recap_bloc.dart';
import '../bloc/recap_event.dart';
import '../bloc/recap_state.dart';

class RecapFormScreen extends StatefulWidget {
  final Recap? recap;
  
  const RecapFormScreen({
    super.key,
    this.recap,
  });

  @override
  State<RecapFormScreen> createState() => _RecapFormScreenState();
}

class _RecapFormScreenState extends State<RecapFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _semesterController;

  bool get isEditMode => widget.recap != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recap?.title ?? '');
    _notesController = TextEditingController(text: widget.recap?.notes ?? '');
    _semesterController = TextEditingController();
    
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
    if (isEditMode && widget.recap != null) {
      // In edit mode, find semester by recap's semesterId
      try {
        final semester = authService.semesters.firstWhere(
          (s) => s.id == widget.recap!.semesterId,
        );
        setState(() {
          _semesterController.text = semester.name;
        });
      } catch (e) {
        // Leave semester unselected if not found
      }
    } else {
      // In create mode, use currently selected semester as initial value
      final selectedSemester = authService.getSelectedSemester();
      setState(() {
        _semesterController.text = selectedSemester?.name ?? '';
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _semesterController.dispose();
    super.dispose();
  }

  void _saveRecap() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final title = _titleController.text.trim();
    final notes = _notesController.text.trim();
    final selectedSemesterName = _semesterController.text.trim();
    
    // Find semester ID from name
    String? semesterId;
    final authService = context.read<AuthService>();
    
    if (selectedSemesterName.isNotEmpty) {
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
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (isEditMode) {
      context.read<RecapBloc>().add(UpdateRecap(
        recapId: widget.recap!.id,
        title: title,
        notes: notes,
        semesterId: semesterId,
      ));
    } else {
      context.read<RecapBloc>().add(CreateRecap(
        title: title,
        notes: notes,
        semesterId: semesterId,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    return BlocListener<RecapBloc, RecapState>(
      listener: (context, state) {
        if (state is RecapCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recap created successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state is RecapUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recap updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state is RecapCreateError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create recap: ${state.message}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is RecapUpdateError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update recap: ${state.message}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: themeService.backgroundColor,
        appBar: AppBar(
          backgroundColor: themeService.backgroundColor,
          elevation: 0,
          title: Text(
            isEditMode ? 'Edit Recap' : 'Create New Session Recap',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _titleController,
                        label: 'Session Title',
                        hint: 'Enter session title',
                        isRequired: true,
                        themeService: themeService,
                      ),
                      const SizedBox(height: 24),
                      _buildSemesterDropdown(),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _notesController,
                        label: 'Session Notes',
                        hint: 'Enter your session notes here...',
                        isRequired: true,
                        maxLines: 12,
                        themeService: themeService,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            BlocBuilder<RecapBloc, RecapState>(
              builder: (context, state) {
                final isLoading = state is RecapCreating || state is RecapUpdating;
                
                return Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: themeService.backgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _saveRecap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A1F2B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Color(0xFF1A1F2B),
                                strokeWidth: 2,
                              )
                            : Text(
                                isEditMode ? 'Update Recap' : 'Create Recap',
                                style: const TextStyle(
                                  color: Color(0xFF1A1F2B),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ThemeService themeService,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (isRequired ? ' *' : ''),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: maxLines == 1 ? 42 : null,
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: themeService.inputPlaceholderColor),
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
                borderSide: BorderSide(color: themeService.borderColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            validator: isRequired
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '$label is required';
                    }
                    return null;
                  }
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSemesterDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Semester *',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
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
      ],
    );
  }
}