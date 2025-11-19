import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import '../../models/user_model.dart' as app_models;
import 'stream_chat_service.dart';

/// Manages chat channel lifecycle and operations
class ChatChannelManager {
  final StreamChatService _streamChatService;
  Channel? _currentChannel;
  String? _currentChannelId;
  
  ChatChannelManager(this._streamChatService);
  
  /// Get current channel
  Channel? get currentChannel => _currentChannel;
  
  /// Get current channel ID
  String? get currentChannelId => _currentChannelId;
  
  /// Initialize and connect to a channel for the given user context
  Future<Channel> initializeChannel({
    required app_models.UserModel user,
    required String token,
    String? selectedStudentId,
  }) async {
    try {
      debugPrint('🔄 [CHANNEL] Initializing channel for user: ${user.id}');
      
      // Connect user to Stream Chat
      await _streamChatService.connectUser(
        userId: user.id,
        token: token,
        userName: user.name,
        userImage: user.avatarUrl,
      );
      
      // Determine channel configuration based on user role
      final channelConfig = _getChannelConfig(user, selectedStudentId);
      
      // Get or create the channel
      final channel = await _getOrCreateChannel(channelConfig);
      
      // Store channel reference
      _currentChannel = channel;
      _currentChannelId = channelConfig.channelId;
      
      debugPrint('✅ [CHANNEL] Channel initialized successfully: ${channelConfig.channelId}');
      return channel;
      
    } catch (e) {
      debugPrint('❌ [CHANNEL] Failed to initialize channel: $e');
      rethrow;
    }
  }
  
  /// Switch to a different channel (for mentors switching students)
  Future<Channel> switchChannel({
    required app_models.UserModel user,
    required String token,
    required String newStudentId,
  }) async {
    try {
      debugPrint('🔄 [CHANNEL] Switching to student channel: $newStudentId');
      
      // For mentors: Force disconnect/reconnect cycle to ensure immediate presence update
      if (user.isMentor) {
        debugPrint('🔄 [PRESENCE] Mentor switching - forcing disconnect/reconnect for immediate presence update');
        
        // Step 1: Stop watching current channel (mentor goes offline to current student)
        await _stopWatchingCurrentChannel();
        
        // Step 2: Disconnect from Stream Chat completely
        await _streamChatService.disconnectUser();
        
        // Step 3: Small delay to ensure presence update propagates
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Step 4: Reconnect to Stream Chat
        await _streamChatService.connectUser(
          userId: user.id,
          token: token,
          userName: user.name,
          userImage: user.avatarUrl,
        );
      } else {
        // For students: just clear state (no channel operations needed)
        _currentChannel = null;
        _currentChannelId = null;
      }
      
      // Initialize new channel (mentor appears online to new student)
      return await initializeChannel(
        user: user,
        token: token,
        selectedStudentId: newStudentId,
      );
      
    } catch (e) {
      debugPrint('❌ [CHANNEL] Failed to switch channel: $e');
      rethrow;
    }
  }
  
  /// Clean up current channel properly
  Future<void> cleanup() async {
    _currentChannel = null;
    _currentChannelId = null;
  }
  
  /// Private: Get channel configuration based on user role
  _ChannelConfig _getChannelConfig(app_models.UserModel user, String? selectedStudentId) {
    if (user.isStudent) {
      // For students, use their ID as channel ID, chat with mentor
      return _ChannelConfig(
        channelId: user.id,
        channelType: 'messaging',
        members: [user.id, user.mentorId ?? ''],
        extraData: {
          'name': 'Chat with ${user.mentorName ?? 'Mentor'}',
          'studentId': user.id,
          'studentName': user.name,
          'mentorId': user.mentorId,
          'mentorName': user.mentorName,
        },
        otherUserId: user.mentorId,
        otherUserName: user.mentorName ?? 'Mentor',
        otherUserImage: user.mentorAvatar,
      );
    } else if (user.isMentor) {
      // For mentors, use selected student's ID as channel ID
      final studentId = selectedStudentId ?? user.students.first.id;
      final student = user.students.firstWhere(
        (s) => s.id == studentId,
        orElse: () => user.students.first,
      );
      
      return _ChannelConfig(
        channelId: studentId,
        channelType: 'messaging',
        members: [user.id, studentId],
        extraData: {
          'name': 'Chat with ${student.name}',
          'studentId': studentId,
          'studentName': student.name,
          'mentorId': user.id,
          'mentorName': user.name,
        },
        otherUserId: studentId,
        otherUserName: student.name,
        otherUserImage: student.avatarUrl,
      );
    } else {
      throw Exception('Unknown user role');
    }
  }
  
  /// Private: Get or create channel with the given configuration
  Future<Channel> _getOrCreateChannel(_ChannelConfig config) async {
    try {
      // First, try to query existing channel
      final channels = await _streamChatService.queryChannels(
        Filter.equal('id', config.channelId),
      );
      
      if (channels.isNotEmpty) {
        debugPrint('✅ [CHANNEL] Found existing channel: ${config.channelId}');
        return channels.first;
      }
      
      // If no channel exists, create it
      debugPrint('🔄 [CHANNEL] Creating new channel: ${config.channelId}');
      final channel = await _streamChatService.getOrCreateChannel(
        channelId: config.channelId,
        channelType: config.channelType,
        members: config.members,
        extraData: config.extraData,
      );
      
      if (channel == null) {
        throw Exception('Failed to create channel');
      }
      
      return channel;
      
    } catch (e) {
      debugPrint('❌ [CHANNEL] Error getting/creating channel: $e');
      rethrow;
    }
  }
  
  
  /// Private: Stop watching current channel (for mentor presence management)
  Future<void> _stopWatchingCurrentChannel() async {
    if (_currentChannel != null) {
      try {
        debugPrint('🔄 [PRESENCE] Stopping watch on channel: $_currentChannelId');
        
        // Don't mark as read - preserve unread state for accurate badges
        // markRead() will be called when user actually opens the chat UI
        
        // Stop watching the channel - this removes presence for this channel
        await _currentChannel!.stopWatching();
        
        debugPrint('✅ [PRESENCE] Stopped watching channel (unread state preserved): $_currentChannelId');
        
      } catch (e) {
        debugPrint('❌ [PRESENCE] Error stopping watch on channel: $e');
      }
    }
  }
}

/// Internal configuration for channel setup
class _ChannelConfig {
  final String channelId;
  final String channelType;
  final List<String> members;
  final Map<String, dynamic> extraData;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserImage;
  
  _ChannelConfig({
    required this.channelId,
    required this.channelType,
    required this.members,
    required this.extraData,
    this.otherUserId,
    this.otherUserName,
    this.otherUserImage,
  });
}