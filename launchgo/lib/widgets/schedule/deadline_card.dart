import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';

import '../../models/deadline_model.dart';
import '../../services/api_service_retrofit.dart';
import '../../theme/app_colors.dart';
import '../status_badge.dart';
import '../documents/document_upload_widget.dart';

class DeadlineCard extends StatefulWidget {
  final DeadlineAssignment assignment;
  final DeadlineCourse course;

  const DeadlineCard({
    super.key,
    required this.assignment,
    required this.course,
  });

  @override
  State<DeadlineCard> createState() => _DeadlineCardState();
}

class _DeadlineCardState extends State<DeadlineCard> {
  late bool _isCompleted;
  String? _status;
  bool _isUpdating = false;
  File? _selectedFile;
  final List<PlatformFile> _selectedFiles = [];
  final Set<String> _deletingAttachmentIds = {};

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.assignment.isCompleted;
    _status = widget.assignment.status;
  }

  @override
  void didUpdateWidget(DeadlineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.assignment.isCompleted != oldWidget.assignment.isCompleted) {
      _isCompleted = widget.assignment.isCompleted;
      _status = widget.assignment.status;
    }
  }

  Color get _borderColor {
    final currentStatus = _status ?? widget.assignment.status;
    return AppColors.getStatusColor(currentStatus);
  }

  Future<void> _toggleCompletion() async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final apiService = context.read<ApiServiceRetrofit>();
      final newCompletionStatus = !_isCompleted;
      
      // Determine the correct status based on completion and due date
      String newStatus;
      if (newCompletionStatus) {
        newStatus = 'completed';
      } else {
        // Check if assignment is overdue when unchecking (using UTC for consistency)
        final nowUtc = DateTime.now().toUtc();
        final dueDateUtc = widget.assignment.dueDate.toUtc();
        final isOverdue = dueDateUtc.isBefore(nowUtc);
        newStatus = isOverdue ? 'overdue' : 'pending';
      }
      
      debugPrint('📝 Updating assignment ${widget.assignment.id} in course ${widget.course.id} to status: $newStatus');
      
      final result = await apiService.updateAssignment(
        widget.course.id,
        widget.assignment.id,
        {'status': newStatus},
      );
      
      debugPrint('✅ Assignment updated successfully. Response: $result');

      setState(() {
        _isCompleted = newCompletionStatus;
        _status = newStatus;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newCompletionStatus ? 'Assignment marked as completed' : 'Assignment marked as pending',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating assignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update assignment'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _deleteAttachment(String attachmentId, StateSetter dialogSetState) async {
    try {
      final apiService = context.read<ApiServiceRetrofit>();
      
      debugPrint('🗑️ Deleting attachment: $attachmentId');
      await apiService.deleteAttachment(
        widget.course.id,
        widget.assignment.id,
        attachmentId,
      );
      
      // Remove the attachment from the local list
      widget.assignment.attachments.removeWhere((attachment) => attachment.id == attachmentId);
      
      // If no attachments left and assignment was completed, reset to pending status
      if (widget.assignment.attachments.isEmpty && _isCompleted) {
        try {
          await apiService.updateAssignment(
            widget.course.id,
            widget.assignment.id,
            {'status': 'pending'},
          );
          _isCompleted = false;
          _status = 'pending';
        } catch (e) {
          debugPrint('❌ Failed to reset assignment status: $e');
        }
      }
      
      // Update the main widget
      if (mounted) {
        setState(() {}); // Update the main assignment card
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Attachment deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error deleting attachment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete attachment'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _showAttachments() {
    // Convert DeadlineAttachment list to Map format for DocumentUploadWidget
    final List<Map<String, dynamic>> existingAttachments = widget.assignment.attachments
        .map((attachment) => {
              'id': attachment.id,
              'name': attachment.name,
              'size': attachment.size,
              'link': attachment.link,
              'mimeType': attachment.mimeType,
            })
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A2332),
              title: const Text(
                'Attachments',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: DocumentUploadWidget(
                    selectedFiles: const [],
                    existingAttachments: existingAttachments,
                    deletingAttachmentIds: _deletingAttachmentIds,
                    onPickFiles: () {}, // No file picking in view mode
                    onRemoveFile: (index) {}, // No file removal in view mode
                    onDeleteExistingAttachment: (attachment) async {
                      dialogSetState(() {
                        _deletingAttachmentIds.add(attachment['id']);
                      });
                      
                      await _deleteAttachment(attachment['id'], dialogSetState);
                      
                      dialogSetState(() {
                        _deletingAttachmentIds.remove(attachment['id']);
                        existingAttachments.removeWhere((a) => a['id'] == attachment['id']);
                      });
                      
                      // Update the main card state
                      setState(() {});
                    },
                    onDownloadAttachment: (attachment) {
                      // TODO: Implement file download/view
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Opening ${attachment['name']}...'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    backgroundColor: const Color(0xFF0F1419),
                    cardColor: const Color(0xFF1A2332),
                    borderColor: Colors.grey[600]!,
                    textColor: Colors.white,
                    textSecondaryColor: Colors.grey[400]!,
                    showTitle: false,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
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
        final file = result.files.first;
        if (file.size > 10485760) { // 10MB limit
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File "${file.name}" exceeds 10MB limit'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedFiles.clear();
          _selectedFiles.add(file);
          if (file.path != null) {
            _selectedFile = File(file.path!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      _selectedFile = null;
    });
  }

  void _deleteExistingAttachment(Map<String, dynamic> attachment) {
    // This would be implemented if needed for existing attachments
  }

  void _downloadAttachment(Map<String, dynamic> attachment) {
    // This would be implemented if needed for existing attachments
  }

  void _showSubmitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A2332),
              title: const Text(
                'Submit Assignment',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submit "${widget.assignment.title}"',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    DocumentUploadWidget(
                      selectedFiles: _selectedFiles,
                      existingAttachments: const [],
                      deletingAttachmentIds: _deletingAttachmentIds,
                      onPickFiles: () async {
                        await _pickFiles();
                        dialogSetState(() {});
                      },
                      onRemoveFile: (index) {
                        _removeFile(index);
                        dialogSetState(() {});
                      },
                      onDeleteExistingAttachment: _deleteExistingAttachment,
                      onDownloadAttachment: _downloadAttachment,
                      backgroundColor: const Color(0xFF0F1419),
                      cardColor: const Color(0xFF1A2332),
                      borderColor: Colors.grey[600]!,
                      textColor: Colors.white,
                      textSecondaryColor: Colors.grey[400]!,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedFile = null;
                      _selectedFiles.clear();
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _submitAssignment();
                  },
                  icon: const Icon(Icons.upload, size: 16),
                  label: const Text('Submit', style: TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54, width: 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitAssignment() async {
    try {
      final apiService = context.read<ApiServiceRetrofit>();
      
      // If a file is selected, upload it first
      if (_selectedFile != null) {
        debugPrint('📎 Uploading file: ${_selectedFile!.path}');
        final uploadResponse = await apiService.uploadAttachment(
          widget.course.id,
          widget.assignment.id,
          _selectedFile!,
          _selectedFile!.path.split('/').last,
        );
        
        // Add the new attachment to the local list
        if (uploadResponse.containsKey('id')) {
          final newAttachment = DeadlineAttachment(
            id: uploadResponse['id'],
            name: uploadResponse['name'] ?? _selectedFile!.path.split('/').last,
            link: uploadResponse['link'] ?? '',
            size: uploadResponse['size'] ?? 0,
            mimeType: uploadResponse['mimeType'] ?? '',
          );
          widget.assignment.attachments.add(newAttachment);
        }
        
        debugPrint('✅ File uploaded successfully');
      }
      
      // Mark assignment as completed
      await apiService.updateAssignment(
        widget.course.id,
        widget.assignment.id,
        {'status': 'completed'},
      );

      setState(() {
        _isCompleted = true;
        _status = 'completed';
        _selectedFile = null; // Clear selected file
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedFile != null 
                  ? 'Assignment "${widget.assignment.title}" submitted with file!'
                  : 'Assignment "${widget.assignment.title}" submitted successfully!'
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting assignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedFile != null 
                  ? 'Failed to submit assignment or upload file'
                  : 'Failed to submit assignment'
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A2332), // Dark background for cards
            border: Border(
              left: BorderSide(
                color: _borderColor,
                width: 6, // Thicker border
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 4),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        InkWell(
          onTap: _isUpdating ? null : _toggleCompletion,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: _StatusIcon(
              isCompleted: _isCompleted,
              isLoading: _isUpdating,
            ),
          ),
        ),
        const SizedBox(width: 0),
        Text(
          widget.assignment.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        StatusBadge.fromStatus(_status ?? widget.assignment.status),
        const Spacer(), // Push everything else to the right
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            'Due ${DateFormat('M/d').format(widget.assignment.dueDate)}',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ),
        // Show attachment indicator only if there are attachments
        if (widget.assignment.attachments.isNotEmpty)
          _AttachmentIndicator(
            count: widget.assignment.attachments.length,
            onTap: () => _showAttachments(),
          ),
        // Show submit button only if not completed AND no attachments exist
        if (!_isCompleted && widget.assignment.attachments.isEmpty)
          _SubmitButton(
            onPressed: () {
              _showSubmitDialog();
            },
          ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final bool isCompleted;
  final bool isLoading;

  const _StatusIcon({
    required this.isCompleted,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
        ),
      );
    }
    
    return Icon(
      isCompleted ? Icons.check_circle : Icons.circle_outlined,
      color: Colors.white,
      size: 24,
    );
  }
}

class _AttachmentIndicator extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const _AttachmentIndicator({
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // If there are attachments, show only the clip icon
    if (count > 0) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 12),
          padding: const EdgeInsets.all(8),
          child: SvgPicture.asset(
            'assets/icons/ic_attachment.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              Colors.white54,
              BlendMode.srcIn,
            ),
          ),
        ),
      );
    }
    
    // If no attachments and there's an onTap (can add files), show the full indicator
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: onTap != null ? Colors.blue.withValues(alpha: 0.2) : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: onTap != null ? Border.all(color: Colors.blue.withValues(alpha: 0.5)) : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.add,
              color: Colors.blue,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              'Add file',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SubmitButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.upload, size: 16),
        label: const Text('Submit', style: TextStyle(fontSize: 14)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white54, width: 1),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          minimumSize: const Size(0, 32),
        ),
      ),
    );
  }
}