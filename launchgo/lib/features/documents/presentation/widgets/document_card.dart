import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/api_service_retrofit.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/theme_service.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/swipeable_card.dart';
import '../../domain/entities/document_entity.dart';

class DocumentCard extends StatelessWidget {
  final DocumentEntity document;
  final VoidCallback? onDeleted;

  const DocumentCard({
    super.key,
    required this.document,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final authService = context.watch<AuthService>();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SwipeableCard(
        canSwipe: authService.permissions.canDeleteDocuments,
        canTap: authService.permissions.canEditDocuments,
        onTap: () => _navigateToEditDocument(context),
        onSwipeToDelete: () => _showDeleteConfirmation(context),
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
  }

  // MARK: - UI Components
  
  Widget _buildTitle(ThemeService themeService) {
    return Text(
      document.title,
      style: TextStyle(
        color: themeService.textColor,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTypeTag(ThemeService themeService) {
    LinearGradient gradient;
    
    switch (document.type) {
      case DocumentType.notes:
        gradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5FD585), Color(0xFF27A353)], // Green gradient
        );
        break;
      case DocumentType.assignment:
        gradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB862E8), Color(0xFF9433C5)], // Purple gradient
        );
        break;
      case DocumentType.studyGuide:
        gradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A8EF2), Color(0xFF0E4FD3)], // Blue gradient
        );
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        document.typeLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLastOpenedText(ThemeService themeService) {
    return Text(
      'Last Opened: ${DateFormat('M/d/yyyy').format(document.lastOpened)}',
      style: TextStyle(
        color: themeService.textSecondaryColor,
        fontSize: 14,
      ),
    );
  }

  Widget _buildOpenButton(ThemeService themeService) {
    LinearGradient gradient;
    
    switch (document.type) {
      case DocumentType.notes:
        gradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5FD585), Color(0xFF27A353)], // Green gradient
        );
        break;
      case DocumentType.assignment:
        gradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB862E8), Color(0xFF9433C5)], // Purple gradient
        );
        break;
      case DocumentType.studyGuide:
        gradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A8EF2), Color(0xFF0E4FD3)], // Blue gradient
        );
        break;
    }
    
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () => _openInGoogleDocs(document.link),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.open_in_new,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              const Text(
                'Open in Google Docs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
      // No box shadow in dark mode
      boxShadow: null,
    );
  }

  TagColors _getTagColors(ThemeService themeService, DocumentType type) {
    // Always use dark theme colors
    switch (type) {
      case DocumentType.studyGuide:
        return const TagColors(
          backgroundColor: AppColors.documentStudyGuideBackground,
          textColor: AppColors.documentStudyGuideText,
        );
      case DocumentType.assignment:
        return const TagColors(
          backgroundColor: AppColors.documentAssignmentBackgroundDark,
          textColor: AppColors.documentAssignmentTextDark,
        );
      case DocumentType.notes:
        return const TagColors(
          backgroundColor: AppColors.documentNotesBackgroundDark,
          textColor: AppColors.documentNotesTextDark,
        );
      default:
        return const TagColors(
          backgroundColor: AppColors.badgeGrey,
          textColor: AppColors.textSecondary,
        );
    }
  }

  // MARK: - Actions

  void _navigateToEditDocument(BuildContext context) async {
    final result = await context.push('/edit-document/${document.id}', extra: document);
    if (result == true && context.mounted) {
      // Notify parent that document was edited
      onDeleted?.call();
    }
  }

  Future<void> _openInGoogleDocs(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${document.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && context.mounted) {
      await _deleteDocument(context);
      return true;
    }
    return false;
  }

  Future<void> _deleteDocument(BuildContext context) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiServiceRetrofit(authService: authService);
      
      await apiService.deleteDocument(document.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // Notify parent that document was deleted
        onDeleted?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete document: ${e.toString()}'),
            backgroundColor: AppColors.error,
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