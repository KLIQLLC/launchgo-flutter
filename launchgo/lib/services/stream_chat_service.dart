import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

class StreamChatService extends ChangeNotifier {
  static const String _apiKey = 'b2xg2crxdpft';
  static StreamChatService? _instance;
  late final StreamChatClient _client;
  bool _isInitialized = false;
  bool _isUserConnected = false;
  
  StreamChatClient get client => _client;
  bool get isInitialized => _isInitialized;
  bool get isUserConnected => _isUserConnected;
  
  StreamChatService() {
    _instance = this;  // Set static reference
    _initializeClient();
  }
  
  // Static getter to access the instance
  static StreamChatService? get instance => _instance;
  
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
    bool setOnline = true,  // Kept for backward compatibility but not used
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
      
      // Connect new user - Stream Chat automatically sets them as online when connected
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
      
      debugPrint('🟢 Stream Chat: User connected successfully - $userId (automatically online)');
      _isUserConnected = true;
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
      _isUserConnected = false;
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
  
  /// Set user status to online (deprecated - Stream Chat handles this automatically)
  @Deprecated('Stream Chat automatically manages online presence when connected')
  Future<void> setUserOnline() async {
    // Stream Chat automatically sets users as online when they connect
    // and offline when they disconnect. No manual action needed.
    debugPrint('🟢 Stream Chat: User is online (managed automatically by Stream)');
  }

  /// Set user status to offline (deprecated - Stream Chat handles this automatically)
  @Deprecated('Stream Chat automatically manages online presence when disconnected')
  Future<void> setUserOffline() async {
    // Stream Chat automatically sets users as offline when they disconnect.
    // To appear offline, disconnect the user instead.
    debugPrint('🟡 Stream Chat: To set offline, disconnect the user');
  }

  /// Automatically connect user if auth info is available
  Future<void> autoConnectUser({
    required String? userId,
    required String? token,
    required String? userName,
    String? userImage,
  }) async {
    // Only connect if we have all required info and not already connected
    if (userId != null && 
        token != null && 
        userName != null && 
        !_isUserConnected &&
        _client.state.currentUser?.id != userId) {
      try {
        await connectUser(
          userId: userId,
          token: token,
          userName: userName,
          userImage: userImage,
        );
        debugPrint('🟢 Stream Chat: Auto-connected user for unread badge (online presence enabled)');
        
        // Query and watch user's channels so they appear online to others
        try {
          final filter = Filter.in_('members', [userId]);
          final channels = await _client.queryChannels(
            filter: filter,
            state: true,
            watch: true,
            presence: true,  // Enable presence tracking
            paginationParams: const PaginationParams(limit: 10),  // Limit to avoid loading too many channels
          ).first;
          
          debugPrint('🟢 Stream Chat: Watching ${channels.length} channels for presence');
          
          // This ensures the user appears online to members of these channels
          for (final channel in channels) {
            // Channels are already being watched from queryChannels with presence: true
            debugPrint('👁️ Watching channel: ${channel.id} with ${channel.memberCount} members');
          }
        } catch (e) {
          debugPrint('⚠️ Stream Chat: Could not watch channels for presence: $e');
        }
      } catch (e) {
        debugPrint('⚠️ Stream Chat: Auto-connect failed (will retry when chat opens): $e');
      }
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