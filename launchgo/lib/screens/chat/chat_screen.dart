import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import '../../services/stream_chat_service.dart';
import '../../widgets/custom_chat_widget.dart';
import '../../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

  Map<String, dynamic> getChatData(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.userInfo;
    if (user == null) {
      throw Exception('User info not loaded');
    }
    
    final userId = user.id;
    final userToken = user.getStreamToken ?? '';
    final userName = user.name;
    final userImage = user.avatarUrl ?? '';
    
    // For students, get mentor info; for mentors, get selected student info
    String? secondUserId;
    String? secondUserName;
    String? secondUserImage;
    
    if (user.isStudent) {
      // Student user - get mentor info
      secondUserId = user.mentorId;
      secondUserName = user.mentorName ?? 'Mentor';
      secondUserImage = user.mentorAvatar;
      
      debugPrint('🔵 [CHAT] Student chat setup - Mentor: $secondUserName ($secondUserId)');
    } else if (user.isMentor) {
      // Mentor user - get selected student info
      final selectedStudent = authService.getSelectedStudent();
      if (selectedStudent != null) {
        secondUserId = selectedStudent.id;
        secondUserName = selectedStudent.name;
        secondUserImage = selectedStudent.avatarUrl;
      } else if (user.students.isNotEmpty) {
        // Fallback to first student if none selected
        final firstStudent = user.students.first;
        secondUserId = firstStudent.id;
        secondUserName = firstStudent.name;
        secondUserImage = firstStudent.avatarUrl;
      } else {
        throw Exception('No students available for chat');
      }
      
      debugPrint('🟢 [CHAT] Mentor chat setup - Student: $secondUserName ($secondUserId)');
    }
    
    return {
      'userId': userId,
      'userToken': userToken,
      'userName': userName,
      'userImage': userImage,
      'secondUserId': secondUserId ?? '',
      'secondUserName': secondUserName ?? 'Unknown',
      'secondUserImage': secondUserImage ?? '',
    };
  }

  Future<Map<String, dynamic>> _initStream(BuildContext context) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final streamChatService = Provider.of<StreamChatService>(context, listen: false);
      final user = authService.userInfo;
      
      if (user == null) {
        throw Exception('User info not loaded');
      }
      
      // Get chat data (handles both student and mentor cases)
      final chatData = getChatData(context);
      
      // Validate token
      if (chatData['userToken'].isEmpty) {
        throw Exception('Stream Chat token not available');
      }
      
      // Connect user to Stream Chat
      await streamChatService.connectUser(
        userId: chatData['userId'],
        token: chatData['userToken'],
        userName: chatData['userName'],
        userImage: chatData['userImage'],
      );
      
      Channel? channel;
      
      if (user.isStudent) {
        // For students, use their ID as channel ID
        final channelId = user.id;
        debugPrint('🔵 [CHAT] Student attempting to join channel: $channelId');
        
        try {
          // First try to query existing channel
          final channels = await streamChatService.queryChannels(
            Filter.equal('id', channelId),
          );
          
          if (channels.isNotEmpty) {
            channel = channels.first;
            debugPrint('🔵 [CHAT] Student found existing channel: ${channel.id}');
          } else {
            // If channel doesn't exist, try to create it
            debugPrint('🔵 [CHAT] Creating new channel for student: $channelId');
            
            // Make sure we have mentor ID
            if (chatData['secondUserId'].isEmpty) {
              throw Exception('Mentor information not available');
            }
            
            channel = await streamChatService.getOrCreateChannel(
              channelId: channelId,
              channelType: 'messaging',
              members: [chatData['userId'], chatData['secondUserId']],
              extraData: {
                'name': 'Chat with ${chatData['secondUserName']}',
                'studentId': user.id,
                'studentName': user.name,
                'mentorId': chatData['secondUserId'],
                'mentorName': chatData['secondUserName'],
              },
            );
          }
        } catch (e) {
          debugPrint('❌ [CHAT] Error with student channel: $e');
          throw Exception('Unable to access chat channel: $e');
        }
      } else if (user.isMentor) {
        // For mentors, use selected student's ID as channel
        final studentId = authService.selectedStudentId ?? authService.getSelectedStudent()?.id;
        
        if (studentId == null) {
          throw Exception('Please select a student to chat with');
        }
        
        debugPrint('🟢 [CHAT] Mentor attempting to join student channel: $studentId');
        
        // Query channels where channel ID equals student ID
        final channels = await streamChatService.queryChannels(
          Filter.equal('id', studentId),
        );
        
        if (channels.isNotEmpty) {
          channel = channels.first;
          debugPrint('🟢 [CHAT] Mentor found channel: ${channel.id}');
        } else {
          // Try alternative query by members
          final altChannels = await streamChatService.queryChannels(
            Filter.and([
              Filter.in_('members', [user.id, studentId]),
              Filter.equal('type', 'messaging'),
            ]),
          );
          
          if (altChannels.isNotEmpty) {
            channel = altChannels.first;
            debugPrint('🟢 [CHAT] Mentor found channel via members: ${channel.id}');
          } else {
            // Create channel with student ID
            debugPrint('🟢 [CHAT] Creating channel for mentor with student: $studentId');
            channel = await streamChatService.getOrCreateChannel(
              channelId: studentId,
              channelType: 'messaging',
              members: [user.id, studentId],
              extraData: {
                'name': 'Chat with Student',
                'studentId': studentId,
                'mentorId': user.id,
                'mentorName': user.name,
              },
            );
          }
        }
      } else {
        throw Exception('Unknown user role');
      }
      
      if (channel == null) {
        throw Exception('Failed to initialize chat channel');
      }
      
      return {'channel': channel};
    } catch (e) {
      debugPrint('❌ [CHAT] Initialization error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _initStream(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Chat'),
              leading: Navigator.of(context).canPop()
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load chat',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}'.replaceAll('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          final channel = snapshot.data!['channel'] as Channel;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Chat'),
              leading: Navigator.of(context).canPop()
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
            ),
            body: CustomChatWidget(
              client: context.read<StreamChatService>().client,
              channel: channel,
            ),
          );
        }
      },
    );
  }
}