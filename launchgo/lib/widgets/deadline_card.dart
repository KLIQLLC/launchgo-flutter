import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../models/deadline_model.dart';
import '../services/api_service_retrofit.dart';
import '../theme/app_colors.dart';
import 'status_badge.dart';

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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A2332),
              title: const Text(
                'Attachments',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.assignment.attachments.length,
                  itemBuilder: (context, index) {
                    final attachment = widget.assignment.attachments[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getFileIcon(attachment.name),
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  attachment.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${(attachment.size / 1024).toStringAsFixed(1)} KB',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              // TODO: Implement file download/view
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Opening ${attachment.name}...'),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.download,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    backgroundColor: const Color(0xFF1A2332),
                                    title: const Text(
                                      'Delete Attachment',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    content: Text(
                                      'Are you sure you want to delete "${attachment.name}"?',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                              
                              if (confirmed == true && mounted) {
                                Navigator.of(context).pop(); // Close the attachments dialog first
                                await _deleteAttachment(attachment.id, setState);
                              }
                            },
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
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
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _showSubmitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A2332),
              title: const Text(
                'Submit Assignment',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Submit "${widget.assignment.title}"',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  // File selection button
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.any,
                        allowMultiple: false,
                      );
                      
                      if (result != null && result.files.isNotEmpty) {
                        setState(() {
                          _selectedFile = File(result.files.first.path!);
                        });
                      }
                    },
                    icon: const Icon(Icons.attach_file, color: Colors.white),
                    label: Text(
                      _selectedFile != null 
                          ? 'File: ${_selectedFile!.path.split('/').last}'
                          : 'Select File (Optional)',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  if (_selectedFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selected: ${_selectedFile!.path.split('/').last}',
                              style: const TextStyle(color: Colors.green, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedFile = null;
                              });
                            },
                            child: const Text(
                              'Remove',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedFile = null;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _submitAssignment();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit'),
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
            horizontal: 16,
            vertical: 18, // Taller cards with more padding
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
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
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.assignment.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        StatusBadge.fromStatus(_status ?? widget.assignment.status),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Text(
          'Due ${DateFormat('M/d').format(widget.assignment.dueDate)}',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
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
          child: Icon(
            Icons.attach_file,
            color: Colors.white54,
            size: 20,
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
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.upload, size: 16),
        label: const Text('Submit'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}