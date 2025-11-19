import 'dart:async';
import 'package:flutter/material.dart';
import 'stream_chat_service.dart';

/// Service focused on managing chat presence and unread counts
class ChatPresenceService {
  final StreamChatService _streamChatService;
  final Map<String, StreamController<int>> _unreadControllers = {};

  ChatPresenceService(this._streamChatService);

  /// Get unread count for a specific student (for mentors)
  int getUnreadCountForStudent(String studentId) {
    return _streamChatService.getUnreadCountForStudent(studentId);
  }

  /// Get stream of unread counts for a specific student
  Stream<int> getUnreadCountStreamForStudent(String studentId) {
    // Check if we already have a controller for this student
    if (_unreadControllers.containsKey(studentId)) {
      return _unreadControllers[studentId]!.stream;
    }

    // Create new controller for this student
    final controller = StreamController<int>.broadcast();
    _unreadControllers[studentId] = controller;

    // Set up the stream from the main service
    _streamChatService.getUnreadCountStreamForStudent(studentId).listen(
      (count) {
        if (!controller.isClosed) {
          controller.add(count);
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
      onDone: () {
        if (!controller.isClosed) {
          controller.close();
        }
        _unreadControllers.remove(studentId);
      },
    );

    return controller.stream;
  }

  /// Clean up resources for a specific student
  void cleanupStudentStream(String studentId) {
    final controller = _unreadControllers[studentId];
    if (controller != null) {
      controller.close();
      _unreadControllers.remove(studentId);
      debugPrint('🧹 [PRESENCE] Cleaned up stream for student: $studentId');
    }
  }

  /// Clean up all resources
  void dispose() {
    for (final controller in _unreadControllers.values) {
      controller.close();
    }
    _unreadControllers.clear();
    debugPrint('🧹 [PRESENCE] Disposed all unread count streams');
  }
}