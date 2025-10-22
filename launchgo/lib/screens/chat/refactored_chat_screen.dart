import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import '../../services/chat/stream_chat_service.dart';
import '../../services/chat/chat_channel_manager.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_chat_widget.dart';

class RefactoredChatScreen extends StatefulWidget {
  const RefactoredChatScreen({super.key});

  @override
  State<RefactoredChatScreen> createState() => _RefactoredChatScreenState();
}

class _RefactoredChatScreenState extends State<RefactoredChatScreen>
    with WidgetsBindingObserver {
  ChatChannelManager? _channelManager;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChannelManager();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupChannelManager();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      debugPrint('🟡 [CHAT] App going to background');
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('🟢 [CHAT] App resumed');
    }
  }

  void _initializeChannelManager() {
    try {
      final streamChatService = context.read<StreamChatService>();
      _channelManager = ChatChannelManager(streamChatService);
      debugPrint('✅ [CHAT] Channel manager initialized');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize chat: $e';
      });
      debugPrint('❌ [CHAT] Failed to initialize channel manager: $e');
    }
  }

  Future<void> _cleanupChannelManager() async {
    if (_channelManager != null) {
      await _channelManager!.cleanup();
      _channelManager = null;
      debugPrint('🔴 [CHAT] Channel manager cleaned up');
    }
  }

  Future<Channel> _initializeChannel() async {
    final authService = context.read<AuthService>();
    final user = authService.userInfo;

    if (user == null) {
      throw Exception('User info not loaded');
    }

    if (user.getStreamToken?.isEmpty ?? true) {
      throw Exception('Stream Chat token not available');
    }

    // For mentors, get selected student ID
    String? selectedStudentId;
    if (user.isMentor) {
      selectedStudentId = authService.selectedStudentId ??
          authService.getSelectedStudent()?.id;
      if (selectedStudentId == null) {
        throw Exception('No students available for chat');
      }
    }

    return await _channelManager!.initializeChannel(
      user: user,
      token: user.getStreamToken!,
      selectedStudentId: selectedStudentId,
    );
  }


  String _getChatTitle() {
    try {
      final authService = context.read<AuthService>();
      final user = authService.userInfo;

      if (user == null) return 'Chat';

      if (user.isStudent) {
        return user.mentorName ?? 'Mentor';
      } else if (user.isMentor) {
        final selectedStudent = authService.getSelectedStudent();
        return selectedStudent?.name ?? 'Student';
      }

      return 'Chat';
    } catch (e) {
      return 'Chat';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Presence switching is now handled in AuthService.selectStudent()

        if (_errorMessage != null) {
          return _buildErrorScreen(_getChatTitle(), _errorMessage!);
        }

        if (_channelManager == null) {
          return _buildLoadingScreen();
        }

        return FutureBuilder<Channel>(
          future: _initializeChannel(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen();
            }

            if (snapshot.hasError) {
              return _buildErrorScreen(
                _getChatTitle(),
                snapshot.error.toString().replaceAll('Exception: ', ''),
              );
            }

            if (!snapshot.hasData) {
              return _buildErrorScreen(_getChatTitle(), 'No chat data available');
            }

            final channel = snapshot.data!;
            return CustomChatWidget(
              client: context.read<StreamChatService>().client,
              channel: channel,
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1828),
        title: const Text('Chat', style: TextStyle(color: Colors.white)),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildErrorScreen(String title, String error) {
    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1828),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _initializeChannelManager();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}