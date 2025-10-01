import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import '../../services/stream_chat_service.dart';
import '../../widgets/custom_chat_widget.dart';
import '../../services/auth_service.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

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
    // Для ментора: первый студент — второй участник
    final student = user.students.isNotEmpty ? user.students.first : null;
    if (student == null) {
      throw Exception('Нет студентов для чата');
    }
    final secondUserId = student.id;
    final secondUserName = student.name;
    final secondUserImage = student.avatarUrl ?? '';
    return {
      'userId': userId,
      'userToken': userToken,
      'userName': userName,
      'userImage': userImage,
      'secondUserId': secondUserId,
      'secondUserName': secondUserName,
      'secondUserImage': secondUserImage,
    };
  }

  Future<Map<String, dynamic>> _initStream(BuildContext context) async {
    final data = getChatData(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final streamChatService = Provider.of<StreamChatService>(context, listen: false);
    final user = authService.userInfo;
    if (user == null) {
      throw Exception('User info not loaded');
    }
    
    // Connect user to Stream Chat
    await streamChatService.connectUser(
      userId: data['userId'],
      token: data['userToken'],
      userName: data['userName'],
      userImage: data['userImage'],
    );
    Channel? channel;
    if (user.isStudent) {
      // Для студента канал — это его id
      final channelId = user.id;
      final channels = await streamChatService.queryChannels(
        Filter.equal('id', channelId),
      );
      if (channels.isEmpty) {
        throw Exception('Чат с id= [32m$channelId [0m не найден');
      }
      channel = channels.first;
      debugPrint('🔵 [CHAT] Student channel id:  [32m [1m [4m [7m${channel.id} [0m');
    } else {
      // Для ментора используем выбранного студента
      final mentorId = user.id;
      final studentId = authService.selectedStudentId ?? authService.getSelectedStudent()?.id;
      if (studentId == null) {
        throw Exception('Не выбран студент для чата');
      }
      final channels = await streamChatService.queryChannels(
        Filter.and([
          Filter.in_('members', [mentorId, studentId]),
        ]),
      );
      if (channels.isEmpty) {
        throw Exception('Нет чата между ментором и студентом');
      }
      channel = channels.first;
      debugPrint('🟢 [CHAT] Mentor channel id:  [32m [1m [4m [7m${channel.id} [0m');
    }
    return {'channel': channel};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _initStream(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Ошибка: \\${snapshot.error}'));
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