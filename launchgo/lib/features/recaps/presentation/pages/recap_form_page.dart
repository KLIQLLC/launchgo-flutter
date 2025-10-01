import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/recap_model.dart';
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

  bool get isEditMode => widget.recap != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recap?.title ?? '');
    _notesController = TextEditingController(text: widget.recap?.notes ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveRecap() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final title = _titleController.text.trim();
    final notes = _notesController.text.trim();

    if (isEditMode) {
      context.read<RecapBloc>().add(UpdateRecap(
        recapId: widget.recap!.id,
        title: title,
        notes: notes,
      ));
    } else {
      context.read<RecapBloc>().add(CreateRecap(
        title: title,
        notes: notes,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: const Color(0xFF0F1419),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F1419),
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
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _notesController,
                        label: 'Session Notes',
                        hint: 'Enter your session notes here...',
                        isRequired: true,
                        maxLines: 12,
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
                    color: const Color(0xFF0F1419),
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
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
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
      ],
    );
  }
}