import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/document_entity.dart';

class DocumentCard extends StatelessWidget {
  final DocumentEntity document;

  const DocumentCard({
    super.key,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2A303E),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              document.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _buildTag(document.typeLabel),
            const SizedBox(height: 12),
            Text(
              'Last Opened: ${DateFormat('M/d/yyyy').format(document.lastOpened)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            if (document.googleDocsUrl != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openInGoogleDocs(document.googleDocsUrl!),
                  icon: const Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Open in Google Docs',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(
                      color: Color(0xFF3A4150),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label) {
    Color backgroundColor;
    Color textColor;

    switch (document.type) {
      case DocumentType.studyGuide:
        backgroundColor = const Color(0xFF2A3F5F);
        textColor = const Color(0xFF8FAFD6);
        break;
      case DocumentType.assignment:
        backgroundColor = const Color(0xFF3A2F4F);
        textColor = const Color(0xFFB99FD8);
        break;
      case DocumentType.notes:
        backgroundColor = const Color(0xFF2F4F3A);
        textColor = const Color(0xFF9FD8B9);
        break;
      default:
        backgroundColor = const Color(0xFF3A3A3A);
        textColor = const Color(0xFFB0B0B0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _openInGoogleDocs(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}