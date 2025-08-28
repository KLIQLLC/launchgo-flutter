import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/api_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/theme_service.dart';
import '../../domain/entities/document_entity.dart';

class DocumentCard extends StatefulWidget {
  final DocumentEntity document;
  final VoidCallback? onDeleted;

  const DocumentCard({
    super.key,
    required this.document,
    this.onDeleted,
  });

  @override
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  double _maxSlideDistance = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final authService = context.watch<AuthService>();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _maxSlideDistance = constraints.maxWidth * 0.4; // 40% of width
          
          return Stack(
            children: [
              // Delete background - only visible when sliding
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              // Main card that slides
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  final slideOffset = _slideAnimation.value * _maxSlideDistance;
                  return Transform.translate(
                    offset: Offset(-slideOffset, 0),
                    child: GestureDetector(
                      onHorizontalDragUpdate: authService.permissions.canDeleteDocuments 
                        ? (details) {
                            if (details.delta.dx < 0) {
                              // Sliding left
                              final progress = (_slideAnimation.value * _maxSlideDistance - details.delta.dx) / _maxSlideDistance;
                              _animationController.value = progress.clamp(0.0, 1.0);
                            } else if (details.delta.dx > 0) {
                              // Sliding right
                              final progress = (_slideAnimation.value * _maxSlideDistance - details.delta.dx) / _maxSlideDistance;
                              _animationController.value = progress.clamp(0.0, 1.0);
                            }
                          }
                        : null, // Disable swipe for students
                      onHorizontalDragEnd: authService.permissions.canDeleteDocuments 
                        ? (details) {
                            if (_slideAnimation.value > 0.5) {
                              // If more than 50% swiped, trigger delete
                              _showDeleteConfirmation(context).then((confirmed) {
                                if (confirmed == true) {
                                  _deleteDocument(context);
                                } else {
                                  _animationController.reverse();
                                }
                              });
                            } else {
                              // Snap back
                              _animationController.reverse();
                            }
                          }
                        : null, // Disable swipe for students
                      onTap: (_slideAnimation.value == 0 && authService.permissions.canEditDocuments) 
                        ? () => _navigateToEditDocument(context) 
                        : null, // Disable edit for students
                      child: Container(
                        decoration: _buildCardDecoration(themeService),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTitle(themeService),
                              const SizedBox(height: 12),
                              _buildTypeTag(themeService),
                              const SizedBox(height: 12),
                              _buildLastOpenedText(themeService),
                              const SizedBox(height: 16),
                              _buildOpenButton(themeService),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // MARK: - UI Components
  
  Widget _buildTitle(ThemeService themeService) {
    return Text(
      widget.document.title,
      style: TextStyle(
        color: themeService.textColor,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTypeTag(ThemeService themeService) {
    final tagColors = _getTagColors(themeService, widget.document.type);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tagColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        widget.document.typeLabel,
        style: TextStyle(
          color: tagColors.textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLastOpenedText(ThemeService themeService) {
    return Text(
      'Last Opened: ${DateFormat('M/d/yyyy').format(widget.document.lastOpened)}',
      style: TextStyle(
        color: themeService.textSecondaryColor,
        fontSize: 14,
      ),
    );
  }

  Widget _buildOpenButton(ThemeService themeService) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _openInGoogleDocs(widget.document.link),
        icon: Icon(
          Icons.open_in_new,
          size: 18,
          color: themeService.textColor,
        ),
        label: Text(
          'Open in Google Docs',
          style: TextStyle(color: themeService.textColor),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(
            color: themeService.borderColor,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  // MARK: - Styling Helpers

  BoxDecoration _buildCardDecoration(ThemeService themeService) {
    return BoxDecoration(
      color: themeService.cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: themeService.borderColor,
        width: 1,
      ),
      boxShadow: themeService.isDarkMode ? null : [
        BoxShadow(
          color: Colors.grey.withValues(alpha: 0.1),
          spreadRadius: 1,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  TagColors _getTagColors(ThemeService themeService, DocumentType type) {
    if (themeService.isDarkMode) {
      return _getDarkThemeTagColors(type);
    } else {
      return _getLightThemeTagColors(type);
    }
  }

  // MARK: - Tag Colors

  TagColors _getDarkThemeTagColors(DocumentType type) {
    switch (type) {
      case DocumentType.studyGuide:
        return const TagColors(
          backgroundColor: Color(0xFF2A3F5F),
          textColor: Color(0xFF8FAFD6),
        );
      case DocumentType.assignment:
        return const TagColors(
          backgroundColor: Color(0xFF3A2F4F),
          textColor: Color(0xFFB99FD8),
        );
      case DocumentType.notes:
        return const TagColors(
          backgroundColor: Color(0xFF2F4F3A),
          textColor: Color(0xFF9FD8B9),
        );
      default:
        return const TagColors(
          backgroundColor: Color(0xFF3A3A3A),
          textColor: Color(0xFFB0B0B0),
        );
    }
  }

  TagColors _getLightThemeTagColors(DocumentType type) {
    switch (type) {
      case DocumentType.studyGuide:
        return TagColors(
          backgroundColor: Colors.blue.withValues(alpha: 0.1),
          textColor: Colors.blue.shade700,
        );
      case DocumentType.assignment:
        return TagColors(
          backgroundColor: Colors.purple.withValues(alpha: 0.1),
          textColor: Colors.purple.shade700,
        );
      case DocumentType.notes:
        return TagColors(
          backgroundColor: Colors.green.withValues(alpha: 0.1),
          textColor: Colors.green.shade700,
        );
      default:
        return TagColors(
          backgroundColor: Colors.grey.withValues(alpha: 0.1),
          textColor: Colors.grey.shade700,
        );
    }
  }

  // MARK: - Actions

  void _navigateToEditDocument(BuildContext context) async {
    final result = await context.push('/edit-document/${widget.document.id}', extra: widget.document);
    if (result == true && context.mounted) {
      // Notify parent that document was edited
      widget.onDeleted?.call();
    }
  }

  Future<void> _openInGoogleDocs(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${widget.document.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDocument(BuildContext context) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService: authService);
      
      await apiService.deleteDocument(widget.document.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Notify parent that document was deleted
        widget.onDeleted?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete document: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// MARK: - Helper Classes

class TagColors {
  final Color backgroundColor;
  final Color textColor;

  const TagColors({
    required this.backgroundColor,
    required this.textColor,
  });
}