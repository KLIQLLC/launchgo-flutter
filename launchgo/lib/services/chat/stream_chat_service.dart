import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import '../push_notification_service.dart';

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
        // Still register FCM token in case it changed
        await _registerPushToken();
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
      debugPrint('🔍 [DEBUG] connectUser called for user: $userId');
      
      // Register FCM token for push notifications
      await _registerPushToken();
      
      // Listen to unread count changes and update app badge
      _setupBadgeListener();
      
      _isUserConnected = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Stream Chat: Error connecting user - $e');
      rethrow;
    }
  }
  
  /// Register FCM token with Stream Chat for push notifications
  Future<void> _registerPushToken() async {
    try {
      final pushNotificationService = PushNotificationService.instance;
      
      // If notification service isn't initialized yet, wait for it
      if (!pushNotificationService.isInitialized) {
        debugPrint('🔔 Stream Chat: Waiting for notification service to initialize...');
        await pushNotificationService.initialize();
      }
      
      if (pushNotificationService.fcmToken != null) {
        debugPrint('🔔 Stream Chat: Registering FCM token: ${pushNotificationService.fcmToken!.substring(0, 20)}...');
        await _client.addDevice(pushNotificationService.fcmToken!, PushProvider.firebase, 
          pushProviderName: 'stage');
        debugPrint('✅ Stream Chat: FCM token registered successfully for push notifications');
        
        // Verify registration by listing devices
        final devicesResponse = await _client.getDevices();
        debugPrint('📱 Stream Chat: Registered devices count: ${devicesResponse.devices.length}');
        for (final device in devicesResponse.devices) {
          debugPrint('📱 Device: ${device.id} - ${device.pushProvider}');
        }
      } else {
        debugPrint('⚠️ Stream Chat: No FCM token available for registration');
        debugPrint('⚠️ NotificationService initialized: ${pushNotificationService.isInitialized}');
        
        // Retry after a short delay
        debugPrint('🔄 Stream Chat: Retrying FCM token registration in 2 seconds...');
        Future.delayed(const Duration(seconds: 2), () async {
          if (pushNotificationService.fcmToken != null) {
            debugPrint('🔔 Stream Chat: Retry - Registering FCM token: ${pushNotificationService.fcmToken!.substring(0, 20)}...');
            await _client.addDevice(pushNotificationService.fcmToken!, PushProvider.firebase, 
          pushProviderName: 'stage');
            debugPrint('✅ Stream Chat: FCM token registered successfully on retry');
          } else {
            debugPrint('❌ Stream Chat: FCM token still not available after retry');
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Stream Chat: Error registering FCM token - $e');
      debugPrint('❌ Error details: ${e.toString()}');
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
      
      // First, try to watch the channel (most common case - channel already exists)
      try {
        await channel.watch(presence: true);
        debugPrint('🟢 Stream Chat: Existing channel watched - $channelId');
      } catch (watchError) {
        debugPrint('⚠️ Stream Chat: Channel not found, cannot proceed - $watchError');
        rethrow; // Don't return channel if we can't watch it
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

  /// Get unread count for a specific student's channel (for mentors)
  int getUnreadCountForStudent(String studentId) {
    try {
      // Look for channel with student ID as the channel ID
      final channels = _client.state.channels;
      
      // First try to find channel by ID
      final channelById = channels.values.where((channel) => channel.id == studentId);
      if (channelById.isNotEmpty) {
        return channelById.first.state?.unreadCount ?? 0;
      }
      
      // Then try to find channel by members
      final channelByMembers = channels.values.where(
        (channel) => channel.state?.members.any((member) => member.userId == studentId) == true
      );
      if (channelByMembers.isNotEmpty) {
        return channelByMembers.first.state?.unreadCount ?? 0;
      }
      
      return 0;
    } catch (e) {
      debugPrint('⚠️ Stream Chat: Error getting unread count for student $studentId: $e');
      return 0;
    }
  }

  /// Manually register FCM token (for testing)
  Future<void> registerPushTokenManually() async {
    await _registerPushToken();
  }

  /// Get a stream that emits whenever the unread count changes for a specific student
  Stream<int> getUnreadCountStreamForStudent(String studentId) {
    try {
      // Use a broadcast stream controller to combine multiple stream sources
      late StreamController<int> controller;
      controller = StreamController<int>.broadcast();
      
      Channel? currentChannel;
      StreamSubscription? channelSubscription;
      StreamSubscription? messageSubscription;
      StreamSubscription? readSubscription;
      StreamSubscription? channelsSubscription;
      
      void emitUnreadCount() {
        if (currentChannel != null && !controller.isClosed) {
          final unreadCount = currentChannel!.state?.unreadCount ?? 0;
          debugPrint('📊 Badge: Emitting unread count: $unreadCount for channel ${currentChannel!.id}');
          controller.add(unreadCount);
        }
      }
      
      void updateUnreadCount() {
        // Find the student's channel
        final channels = _client.state.channels;
        Channel? studentChannel;
        
        debugPrint('🔍 Badge: Looking for channel for student $studentId, available channels: ${channels.keys.toList()}');
        
        // First try to find by ID
        final channelById = channels.values.where((channel) => channel.id == studentId);
        if (channelById.isNotEmpty) {
          studentChannel = channelById.first;
          debugPrint('✅ Badge: Found channel by ID: ${studentChannel.id}');
        } else {
          // Then try by members
          final channelByMembers = channels.values.where(
            (channel) => channel.state?.members.any((member) => member.userId == studentId) == true
          );
          if (channelByMembers.isNotEmpty) {
            studentChannel = channelByMembers.first;
            debugPrint('✅ Badge: Found channel by members: ${studentChannel.id}');
          }
        }
        
        if (studentChannel == null) {
          debugPrint('❌ Badge: No channel found for student $studentId');
          if (!controller.isClosed) {
            controller.add(0);
          }
          return;
        }
        
        // If we found a new channel or the channel changed
        if (studentChannel != currentChannel) {
          // Cancel previous subscriptions
          channelSubscription?.cancel();
          messageSubscription?.cancel();
          readSubscription?.cancel();
          
          currentChannel = studentChannel;
          
          debugPrint('🔄 Badge: Channel changed to ${currentChannel?.id}, setting up new subscriptions');
          
          // Subscribe to the new channel's state if it exists
          if (currentChannel != null) {
            // Listen to channel state changes
            channelSubscription = currentChannel!.state?.channelStateStream.listen((_) {
              debugPrint('📊 Badge: Channel state changed');
              emitUnreadCount();
            });
            
            // Listen to new messages
            messageSubscription = currentChannel!.on(EventType.messageNew).listen((event) {
              debugPrint('💬 Badge: New message received');
              // Small delay to let the unread count update
              Future.delayed(const Duration(milliseconds: 100), () {
                emitUnreadCount();
              });
            });
            
            // Listen to read events
            readSubscription = currentChannel!.on(EventType.messageRead).listen((event) {
              debugPrint('👁️ Badge: Messages marked as read');
              // Small delay to let the unread count update
              Future.delayed(const Duration(milliseconds: 100), () {
                emitUnreadCount();
              });
            });
          }
        }
        
        // Emit current unread count
        emitUnreadCount();
      }
      
      // Listen to channels changes
      channelsSubscription = _client.state.channelsStream.listen((_) {
        updateUnreadCount();
      });
      
      // Also listen to global message events for this channel
      _client.on(EventType.messageNew, EventType.messageRead, EventType.notificationMarkRead).listen((event) {
        // Check if the event is for our channel
        if (event.channelId == studentId || 
            (currentChannel != null && event.channelId == currentChannel!.id)) {
          debugPrint('🔔 Badge: Global event for our channel: ${event.type}');
          Future.delayed(const Duration(milliseconds: 100), () {
            emitUnreadCount();
          });
        }
      });
      
      // Initial update
      updateUnreadCount();
      
      // Clean up when stream is cancelled
      controller.onCancel = () {
        channelSubscription?.cancel();
        messageSubscription?.cancel();
        readSubscription?.cancel();
        channelsSubscription?.cancel();
      };
      
      return controller.stream.distinct();
    } catch (e) {
      debugPrint('⚠️ Stream Chat: Error creating unread count stream for student $studentId: $e');
      return Stream.value(0);
    }
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

  /// Set up listener to update app icon badge with unread count
  void _setupBadgeListener() {
    // Listen to current user changes to update app badge
    // Works for both students and mentors (shows total unread count)
    _client.state.currentUserStream.listen((user) {
      if (user != null) {
        final unreadCount = user.totalUnreadCount;
        _updateAppBadge(unreadCount);
      }
    });
  }

  /// Update app icon badge with unread count
  void _updateAppBadge(int count) async {
    try {
      if (await FlutterAppBadger.isAppBadgeSupported()) {
        if (count > 0) {
          await FlutterAppBadger.updateBadgeCount(count);
          debugPrint('🔢 App badge updated: $count');
        } else {
          await FlutterAppBadger.removeBadge();
          debugPrint('🔢 App badge removed');
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating app badge: $e');
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