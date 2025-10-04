import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'dart:io';

class CustomAttachmentHandler {
  // Constants
  static const int _maxImageWidth = 1920;
  static const int _maxImageHeight = 1920;
  static const int _imageQuality = 85;
  static const int _maxVideoSizeMB = 100;
  static const int _maxFileSizeMB = 50;
  static const Duration _maxVideoDuration = Duration(minutes: 5);
  
  // File size limits in bytes
  static const int _maxVideoSizeBytes = _maxVideoSizeMB * 1024 * 1024;
  static const int _maxFileSizeBytes = _maxFileSizeMB * 1024 * 1024;
  
  // UI Constants
  static const Color _primaryColor = Color(0xFF7B8CDE);
  static const Color _backgroundColor = Color(0xFF1A2332);
  static const Color _errorColor = Colors.red;
  static const Color _warningColor = Colors.orange;
  static const Color _textColor = Colors.white;

  static Future<void> showAttachmentOptions({
    required BuildContext context,
    required StreamMessageInputController messageInputController,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: _backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => _AttachmentBottomSheet(
        messageInputController: messageInputController,
      ),
    );
  }

  // Helper methods for showing feedback
  static void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: _primaryColor,
      ),
    );
  }

  static void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _errorColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void _showWarningMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _warningColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _AttachmentBottomSheet extends StatelessWidget {
  final StreamMessageInputController messageInputController;

  const _AttachmentBottomSheet({
    required this.messageInputController,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AttachmentOption(
              icon: Icons.photo_library,
              label: 'Photo Library',
              onTap: () => _handlePhotoLibrary(context),
            ),
            _AttachmentOption(
              icon: Icons.camera_alt,
              label: 'Camera',
              onTap: () => _handleCamera(context),
            ),
            _AttachmentOption(
              icon: Icons.videocam,
              label: 'Video',
              onTap: () => _handleVideo(context),
            ),
            _AttachmentOption(
              icon: Icons.attach_file,
              label: 'File',
              onTap: () => _handleFile(context),
            ),
            const SizedBox(height: 8),
            _AttachmentOption(
              icon: Icons.cancel,
              label: 'Cancel',
              onTap: () => Navigator.pop(context),
              isCancel: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePhotoLibrary(BuildContext context) async {
    Navigator.pop(context);
    await _AttachmentPicker.pickImage(
      context: context,
      source: ImageSource.gallery,
      messageInputController: messageInputController,
    );
  }

  Future<void> _handleCamera(BuildContext context) async {
    Navigator.pop(context);
    await _AttachmentPicker.pickImage(
      context: context,
      source: ImageSource.camera,
      messageInputController: messageInputController,
    );
  }

  Future<void> _handleVideo(BuildContext context) async {
    Navigator.pop(context);
    await _AttachmentPicker.pickVideo(
      context: context,
      messageInputController: messageInputController,
    );
  }

  Future<void> _handleFile(BuildContext context) async {
    Navigator.pop(context);
    await _AttachmentPicker.pickFile(
      context: context,
      messageInputController: messageInputController,
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isCancel;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isCancel = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isCancel ? CustomAttachmentHandler._errorColor : CustomAttachmentHandler._primaryColor,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isCancel ? CustomAttachmentHandler._errorColor : CustomAttachmentHandler._textColor,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _AttachmentPicker {
  static final ImagePicker _imagePicker = ImagePicker();

  static Future<void> pickImage({
    required BuildContext context,
    required ImageSource source,
    required StreamMessageInputController messageInputController,
  }) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: CustomAttachmentHandler._maxImageWidth.toDouble(),
        maxHeight: CustomAttachmentHandler._maxImageHeight.toDouble(),
        imageQuality: CustomAttachmentHandler._imageQuality,
      );
      
      if (image != null && context.mounted) {
        await _processImageFile(context, image, messageInputController);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (context.mounted) {
        CustomAttachmentHandler._showErrorMessage(
          context, 
          'Failed to pick image: ${e.toString()}'
        );
      }
    }
  }

  static Future<void> pickVideo({
    required BuildContext context,
    required StreamMessageInputController messageInputController,
  }) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: CustomAttachmentHandler._maxVideoDuration,
      );
      
      if (video != null && context.mounted) {
        await _processVideoFile(context, video, messageInputController);
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
      if (context.mounted) {
        CustomAttachmentHandler._showErrorMessage(
          context, 
          'Failed to pick video: ${e.toString()}'
        );
      }
    }
  }

  static Future<void> pickFile({
    required BuildContext context,
    required StreamMessageInputController messageInputController,
  }) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );
      
      if (result != null && result.files.isNotEmpty && context.mounted) {
        await _processGenericFile(context, result.files.first, messageInputController);
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (context.mounted) {
        CustomAttachmentHandler._showErrorMessage(
          context, 
          'Failed to pick file: ${e.toString()}'
        );
      }
    }
  }

  static Future<void> _processImageFile(
    BuildContext context,
    XFile image,
    StreamMessageInputController messageInputController,
  ) async {
    final file = File(image.path);
    final attachment = Attachment(
      type: 'image',
      file: AttachmentFile(
        size: await file.length(),
        path: file.path,
        bytes: await file.readAsBytes(),
      ),
    );
    
    messageInputController.addAttachment(attachment);
    if (context.mounted) {
      CustomAttachmentHandler._showSuccessMessage(
        context, 
        'Image attached - tap send to upload'
      );
    }
  }

  static Future<void> _processVideoFile(
    BuildContext context,
    XFile video,
    StreamMessageInputController messageInputController,
  ) async {
    final file = File(video.path);
    final fileSize = await file.length();
    
    if (fileSize > CustomAttachmentHandler._maxVideoSizeBytes) {
      if (context.mounted) {
        CustomAttachmentHandler._showWarningMessage(
          context,
          'Video file is too large. Maximum size is ${CustomAttachmentHandler._maxVideoSizeMB}MB.'
        );
      }
      return;
    }
    
    final attachment = Attachment(
      type: 'video',
      file: AttachmentFile(
        size: fileSize,
        path: file.path,
        bytes: await file.readAsBytes(),
      ),
    );
    
    messageInputController.addAttachment(attachment);
    if (context.mounted) {
      CustomAttachmentHandler._showSuccessMessage(
        context, 
        'Video attached - tap send to upload'
      );
    }
  }

  static Future<void> _processGenericFile(
    BuildContext context,
    PlatformFile platformFile,
    StreamMessageInputController messageInputController,
  ) async {
    if (platformFile.path == null) {
      CustomAttachmentHandler._showErrorMessage(context, 'File path is invalid');
      return;
    }

    final file = File(platformFile.path!);
    final fileSize = await file.length();
    
    if (fileSize > CustomAttachmentHandler._maxFileSizeBytes) {
      if (context.mounted) {
        CustomAttachmentHandler._showWarningMessage(
          context,
          'File is too large. Maximum size is ${CustomAttachmentHandler._maxFileSizeMB}MB.'
        );
      }
      return;
    }
    
    final attachment = Attachment(
      type: 'file',
      title: platformFile.name,
      file: AttachmentFile(
        size: fileSize,
        path: file.path,
        bytes: await file.readAsBytes(),
      ),
    );
    
    messageInputController.addAttachment(attachment);
    if (context.mounted) {
      CustomAttachmentHandler._showSuccessMessage(
        context, 
        'File attached - tap send to upload'
      );
    }
  }
}