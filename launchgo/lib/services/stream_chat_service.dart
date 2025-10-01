import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

class StreamChatService extends ChangeNotifier {
  static const String _apiKey = 'b2xg2crxdpft';
  late final StreamChatClient _client;
  bool _isInitialized = false;
  
  StreamChatClient get client => _client;
  bool get isInitialized => _isInitialized;
  
  StreamChatService() {
    _initializeClient();
  }
  
  void _initializeClient() {
    _client = StreamChatClient(
      _apiKey,
      logLevel: Level.INFO,
    );
    _isInitialized = true;
    notifyListeners();
  }
  
  Future<void> connectUser({
    required String userId,
    required String token,
    required String userName,
    String? userImage,
  }) async {
    try {
      // Check if already connected with the same user
      if (_client.state.currentUser?.id == userId) {
        debugPrint('🟢 Stream Chat: User already connected');
        return;
      }
      
      // Disconnect previous user if any
      if (_client.state.currentUser != null) {
        await disconnectUser();
      }
      
      // Connect new user
      await _client.connectUser(
        User(
          id: userId,
          extraData: {
            'name': userName,
            if (userImage != null) 'image': userImage,
          },
        ),
        token,
      );
      
      debugPrint('🟢 Stream Chat: User connected successfully - $userId');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Stream Chat: Error connecting user - $e');
      rethrow;
    }
  }
  
  Future<void> disconnectUser() async {
    try {
      await _client.disconnectUser();
      debugPrint('🟡 Stream Chat: User disconnected');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Stream Chat: Error disconnecting user - $e');
    }
  }
  
  Future<Channel?> getOrCreateChannel({
    required String channelId,
    String channelType = 'messaging',
    Map<String, dynamic>? extraData,
    List<String>? members,
  }) async {
    try {
      final channel = _client.channel(
        channelType,
        id: channelId,
        extraData: extraData,
      );
      
      if (members != null && members.isNotEmpty) {
        await channel.create();
        await channel.addMembers(members);
      } else {
        await channel.watch();
      }
      
      debugPrint('🟢 Stream Chat: Channel ready - $channelId');
      return channel;
    } catch (e) {
      debugPrint('❌ Stream Chat: Error with channel - $e');
      return null;
    }
  }
  
  Future<List<Channel>> queryChannels(Filter filter) async {
    try {
      final channels = await _client.queryChannels(
        filter: filter,
        state: true,
        watch: true,
      ).first;
      
      debugPrint('🟢 Stream Chat: Found ${channels.length} channels');
      return channels;
    } catch (e) {
      debugPrint('❌ Stream Chat: Error querying channels - $e');
      return [];
    }
  }
  
  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }
}