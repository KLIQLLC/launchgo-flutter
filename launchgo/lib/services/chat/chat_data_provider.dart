import '../../models/user_model.dart';

/// Provides chat-related data and configuration
class ChatDataProvider {
  /// Extract chat data from user context
  static Map<String, dynamic> getChatData({
    required UserModel user,
    String? selectedStudentId,
  }) {
    if (user.isStudent) {
      return _getStudentChatData(user);
    } else if (user.isMentor) {
      return _getMentorChatData(user, selectedStudentId);
    } else {
      throw Exception('Unknown user role');
    }
  }

  /// Get chat data for student users
  static Map<String, dynamic> _getStudentChatData(UserModel user) {
    return {
      'userId': user.id,
      'userToken': user.chatGetStreamToken ?? '',
      'userName': user.name,
      'userImage': user.avatarUrl ?? '',
      'secondUserId': user.mentorId ?? '',
      'secondUserName': user.mentorName ?? 'Mentor',
      'secondUserImage': user.mentorAvatar ?? '',
      'channelId': user.id, // Student's ID as channel ID
      'chatTitle': user.mentorName ?? 'Mentor',
    };
  }

  /// Get chat data for mentor users
  static Map<String, dynamic> _getMentorChatData(UserModel user, String? selectedStudentId) {
    // Determine which student to chat with
    final studentId = selectedStudentId ?? user.students.firstOrNull?.id;
    if (studentId == null) {
      throw Exception('No students available for chat');
    }

    final student = user.students.where((s) => s.id == studentId).firstOrNull;
    if (student == null) {
      throw Exception('Selected student not found');
    }

    return {
      'userId': user.id,
      'userToken': user.chatGetStreamToken ?? '',
      'userName': user.name,
      'userImage': user.avatarUrl ?? '',
      'secondUserId': student.id,
      'secondUserName': student.name,
      'secondUserImage': student.avatarUrl ?? '',
      'channelId': student.id, // Student's ID as channel ID
      'chatTitle': student.name,
    };
  }

  /// Validate chat data
  static void validateChatData(Map<String, dynamic> chatData) {
    final requiredFields = ['userId', 'userToken', 'channelId'];
    
    for (final field in requiredFields) {
      if (chatData[field] == null || chatData[field].toString().isEmpty) {
        throw Exception('Missing required chat data: $field');
      }
    }
  }

  /// Get chat title for app bar
  static String getChatTitle(UserModel user, String? selectedStudentId) {
    try {
      final chatData = getChatData(user: user, selectedStudentId: selectedStudentId);
      return chatData['chatTitle'] ?? 'Chat';
    } catch (e) {
      return 'Chat';
    }
  }
}