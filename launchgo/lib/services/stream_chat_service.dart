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
    
    // Handle WebSocket errors globally
    _client.on().listen((event) {
      if (event.type == 'connection.error') {
        debugPrint('🟡 Stream Chat: Connection error handled gracefully');
      }
    }).onError((error) {
      if (error.toString().contains('close code must be 1000 or in the range 3000-4999')) {
        debugPrint('🟡 Stream Chat: WebSocket close code error handled gracefully');
      } else {
        debugPrint('❌ Stream Chat: Unexpected error - $error');
      }
    });
    
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
      // Check if client is connected before attempting to disconnect
      if (_client.state.currentUser != null) {
        await _client.disconnectUser();
        debugPrint('🟡 Stream Chat: User disconnected');
      } else {
        debugPrint('🟡 Stream Chat: No user to disconnect');
      }
      notifyListeners();
    } catch (e) {
      // Handle WebSocket close code errors gracefully
      if (e.toString().contains('close code must be 1000 or in the range 3000-4999')) {
        debugPrint('🟡 Stream Chat: WebSocket close code error (handled gracefully)');
      } else {
        debugPrint('❌ Stream Chat: Error disconnecting user - $e');
      }
      notifyListeners();
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
        // Watch the channel with presence enabled
        await channel.watch(presence: true);
      } else {
        // Watch the channel with presence enabled
        await channel.watch(presence: true);
      }
      
      debugPrint('🟢 Stream Chat: Channel ready with presence tracking - $channelId');
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
        presence: true,  // Enable presence tracking
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
    try {
      _client.dispose();
    } catch (e) {
      // Handle WebSocket close code errors gracefully during disposal
      if (e.toString().contains('close code must be 1000 or in the range 3000-4999')) {
        debugPrint('🟡 Stream Chat: WebSocket close code error during disposal (handled gracefully)');
      } else {
        debugPrint('❌ Stream Chat: Error disposing client - $e');
      }
    }
    super.dispose();
  }
}