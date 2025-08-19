import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/theme_service.dart';
import '../../domain/entities/document_entity.dart';

class DocumentCard extends StatelessWidget {
  final DocumentEntity document;

  const DocumentCard({
    super.key,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    final tagColors = _getTagColors(themeService, document.type);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tagColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        document.typeLabel,
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
      'Last Opened: ${DateFormat('M/d/yyyy').format(document.lastOpened)}',
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
        onPressed: () => _openInGoogleDocs(document.link),
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

  Future<void> _openInGoogleDocs(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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