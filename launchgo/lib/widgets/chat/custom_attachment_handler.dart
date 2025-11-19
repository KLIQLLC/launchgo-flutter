import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
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
    final parentContext = context; // Store the original context
    await showModalBottomSheet(
      context: context,
      backgroundColor: _backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext modalContext) {
        return _AttachmentBottomSheet(
          messageInputController: messageInputController,
          parentContext: parentContext,
        );
      },
    );
  }

  // Permission handling methods
  static Future<bool> _requestCameraPermission() async {
    final cameraStatus = await Permission.camera.request();
    return cameraStatus.isGranted;
  }

  static Future<bool> _requestPhotosPermission() async {
    if (Platform.isAndroid) {
      // Try storage permission first (works for most Android versions)
      try {
        final storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) return true;
        
        // For Android 13+, try photos permission
        final photosStatus = await Permission.photos.request();
        return photosStatus.isGranted;
      } catch (e) {
        return false;
      }
    }

    // iOS: Request photos permission
    final photosStatus = await Permission.photos.request();
    return photosStatus.isGranted;
  }

  static Future<bool> _requestMicrophonePermission() async {
    final micStatus = await Permission.microphone.request();
    return micStatus.isGranted;
  }

  static void _showPermissionDeniedDialog(BuildContext context, String permissionType) {
    final settingsText = Platform.isIOS 
        ? 'Settings > Privacy & Security > $permissionType > launchgo'
        : 'Settings > Apps > launchgo > Permissions';
        
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _backgroundColor,
          title: Text(
            'Permission Required',
            style: TextStyle(color: _textColor),
          ),
          content: Text(
            'Please enable $permissionType permission in $settingsText',
            style: TextStyle(color: _textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: _textColor)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: Text('Settings', style: TextStyle(color: _primaryColor)),
            ),
          ],
        );
      },
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
  final BuildContext parentContext;

  const _AttachmentBottomSheet({
    required this.messageInputController,
    required this.parentContext,
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
            // _AttachmentOption(
            //   icon: Icons.videocam,
            //   label: 'Video',
            //   onTap: () => _handleVideo(context),
            // ),
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
    
    // Request photos permission
    final hasPermission = await CustomAttachmentHandler._requestPhotosPermission();
    
    if (!hasPermission) {
      if (parentContext.mounted) {
        CustomAttachmentHandler._showPermissionDeniedDialog(parentContext, 'Photos');
      }
      return;
    }
    
    if (parentContext.mounted) {
      await _AttachmentPicker.pickImage(
        context: parentContext,
        source: ImageSource.gallery,
        messageInputController: messageInputController,
      );
    }
  }

  Future<void> _handleCamera(BuildContext context) async {
    Navigator.pop(context);
    
    // Request camera permission
    final hasPermission = await CustomAttachmentHandler._requestCameraPermission();
    
    if (!hasPermission) {
      if (parentContext.mounted) {
        CustomAttachmentHandler._showPermissionDeniedDialog(parentContext, 'Camera');
      }
      return;
    }
    
    if (parentContext.mounted) {
      await _AttachmentPicker.pickImage(
        context: parentContext,
        source: ImageSource.camera,
        messageInputController: messageInputController,
      );
    }
  }

  Future<void> _handleVideo(BuildContext context) async {
    Navigator.pop(context);
    
    // Request both photos and microphone permission for video
    final hasPhotosPermission = await CustomAttachmentHandler._requestPhotosPermission();
    final hasMicPermission = await CustomAttachmentHandler._requestMicrophonePermission();
    
    if (!hasPhotosPermission) {
      if (parentContext.mounted) {
        CustomAttachmentHandler._showPermissionDeniedDialog(parentContext, 'Photos');
      }
      return;
    }
    
    if (!hasMicPermission) {
      if (parentContext.mounted) {
        CustomAttachmentHandler._showPermissionDeniedDialog(parentContext, 'Microphone');
      }
      return;
    }
    
    if (parentContext.mounted) {
      await _AttachmentPicker.pickVideo(
        context: parentContext,
        messageInputController: messageInputController,
      );
    }
  }

  Future<void> _handleFile(BuildContext context) async {
    Navigator.pop(context);
    await _AttachmentPicker.pickFile(
      context: parentContext, // Use parent context instead of modal context
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
      
      if (image != null) {
        // Process the image even if context is not mounted - the controller is still valid
        await _processImageFileWithoutContext(image, messageInputController);
      }
    } catch (e) {
      if (context.mounted) {
        String errorMessage = 'Failed to pick image';
        if (e.toString().contains('photo_access_denied') || 
            e.toString().contains('camera_access_denied') ||
            e.toString().contains('Permission denied')) {
          final settingsPath = Platform.isIOS 
              ? 'Settings > Privacy & Security > Camera/Photos > launchgo'
              : 'Settings > Apps > launchgo > Permissions';
          errorMessage = 'Camera/Photos permission denied. Please enable in $settingsPath';
        } else {
          errorMessage = 'Failed to pick image: ${e.toString()}';
        }
        CustomAttachmentHandler._showErrorMessage(context, errorMessage);
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
      
      if (video != null) {
        await _processVideoFile(context, video, messageInputController);
      }
    } catch (e) {
      if (context.mounted) {
        String errorMessage = 'Failed to pick video';
        if (e.toString().contains('photo_access_denied') || 
            e.toString().contains('Permission denied')) {
          final settingsPath = Platform.isIOS 
              ? 'Settings > Privacy & Security > Photos > launchgo'
              : 'Settings > Apps > launchgo > Permissions';
          errorMessage = 'Photos/Storage permission denied. Please enable in $settingsPath';
        } else {
          errorMessage = 'Failed to pick video: ${e.toString()}';
        }
        CustomAttachmentHandler._showErrorMessage(context, errorMessage);
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
      if (context.mounted) {
        CustomAttachmentHandler._showErrorMessage(
          context, 
          'Failed to pick file: ${e.toString()}'
        );
      }
    }
  }


  static Future<void> _processImageFileWithoutContext(
    XFile image,
    StreamMessageInputController messageInputController,
  ) async {
    final file = File(image.path);
    
    if (!await file.exists()) {
      throw Exception('Image file not found');
    }
    
    final fileSize = await file.length();
    final fileName = image.path.split('/').last;
    final bytes = await file.readAsBytes();
    
    // Create attachment with all required fields
    final attachment = Attachment(
      type: 'image',
      title: fileName,
      file: AttachmentFile(
        size: fileSize,
        path: file.path,
        bytes: bytes,
        name: fileName,
      ),
    );
    
    messageInputController.addAttachment(attachment);
  }

  static Future<void> _processVideoFile(
    BuildContext context,
    XFile video,
    StreamMessageInputController messageInputController,
  ) async {
    try {
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
    } catch (e) {
      if (context.mounted) {
        CustomAttachmentHandler._showErrorMessage(
          context,
          'Failed to process video: ${e.toString()}'
        );
      }
    }
  }

  static Future<void> _processGenericFile(
    BuildContext context,
    PlatformFile platformFile,
    StreamMessageInputController messageInputController,
  ) async {
    try {
      if (platformFile.path == null) {
        if (context.mounted) {
          CustomAttachmentHandler._showErrorMessage(context, 'File path is invalid');
        }
        return;
      }

      final file = File(platformFile.path!);
      
      if (!await file.exists()) {
        if (context.mounted) {
          CustomAttachmentHandler._showErrorMessage(context, 'Selected file not found');
        }
        return;
      }
      
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
      
      final bytes = await file.readAsBytes();
      
      final attachment = Attachment(
        type: 'file',
        title: platformFile.name,
        file: AttachmentFile(
          size: fileSize,
          path: file.path,
          bytes: bytes,
          name: platformFile.name,
        ),
      );
      
      messageInputController.addAttachment(attachment);
    } catch (e) {
      if (context.mounted) {
        CustomAttachmentHandler._showErrorMessage(
          context,
          'Failed to process file: ${e.toString()}'
        );
      }
    }
  }
}