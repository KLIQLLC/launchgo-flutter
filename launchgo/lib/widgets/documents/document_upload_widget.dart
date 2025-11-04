import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_colors.dart';

class DocumentUploadWidget extends StatelessWidget {
  final List<PlatformFile> selectedFiles;
  final List<Map<String, dynamic>> existingAttachments;
  final Set<String> deletingAttachmentIds;
  final VoidCallback onPickFiles;
  final Function(int) onRemoveFile;
  final Function(Map<String, dynamic>) onDeleteExistingAttachment;
  final Function(Map<String, dynamic>) onDownloadAttachment;
  final Color backgroundColor;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color textSecondaryColor;
  final bool showTitle;
  final String title;

  const DocumentUploadWidget({
    super.key,
    required this.selectedFiles,
    required this.existingAttachments,
    required this.deletingAttachmentIds,
    required this.onPickFiles,
    required this.onRemoveFile,
    required this.onDeleteExistingAttachment,
    required this.onDownloadAttachment,
    required this.backgroundColor,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.textSecondaryColor,
    this.showTitle = true,
    this.title = 'Attach Documents',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
        ],
        _buildDocumentUploadArea(),
      ],
    );
  }

  Widget _buildDocumentUploadArea() {
    return Column(
      children: [
        // Show existing attachments if any
        if (existingAttachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Existing attachment:',
            style: TextStyle(
              color: textSecondaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          for (final attachment in existingAttachments)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: deletingAttachmentIds.contains(attachment['id'])
                    ? cardColor.withValues(alpha: 0.3)
                    : cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: deletingAttachmentIds.contains(attachment['id'])
                      ? AppColors.error.withValues(alpha: 0.3)
                      : borderColor.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getFileIconForName(attachment['name'] ?? 'file'),
                    size: 20,
                    color: textSecondaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onDownloadAttachment(attachment),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attachment['name'] ?? 'Unknown file',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (attachment['size'] != null)
                            Text(
                              _formatFileSize(attachment['size'] is int ? attachment['size'] : 0),
                              style: TextStyle(
                                color: textSecondaryColor,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Download button
                      IconButton(
                        icon: Icon(
                          Icons.download,
                          size: 20,
                          color: textSecondaryColor,
                        ),
                        onPressed: () => onDownloadAttachment(attachment),
                        tooltip: 'Download',
                      ),
                      // Delete button
                      IconButton(
                        icon: deletingAttachmentIds.contains(attachment['id'])
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
                                ),
                              )
                            : SvgPicture.asset(
                                'assets/icons/ic_delete.svg',
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  AppColors.error,
                                  BlendMode.srcIn,
                                ),
                              ),
                        onPressed: deletingAttachmentIds.contains(attachment['id']) 
                            ? null 
                            : () => onDeleteExistingAttachment(attachment),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],
        
        // File picker button - only show if no files are selected and no existing attachments
        if (selectedFiles.isEmpty && existingAttachments.isEmpty)
          GestureDetector(
            onTap: onPickFiles,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.attach_file,
                      size: 20,
                      color: textSecondaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attach file',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Maximum 1 file, 30MB',
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Supports PDF, Word, Images, and Text files',
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: textSecondaryColor,
                  ),
                ],
              ),
            ),
          ),
        // Selected files list
        if (selectedFiles.isNotEmpty) ...[ 
          const SizedBox(height: 12),
          for (int i = 0; i < selectedFiles.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    _getFileIcon(selectedFiles[i].extension),
                    size: 20,
                    color: textSecondaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedFiles[i].name,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatFileSize(selectedFiles[i].size),
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => onRemoveFile(i),
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: textSecondaryColor,
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

  IconData _getFileIconForName(String fileName) {
    final extension = fileName.split('.').lastOrNull;
    return _getFileIcon(extension);
  }
}