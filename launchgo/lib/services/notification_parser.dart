/// Utility class for parsing notification data
class NotificationParser {
  /// Check if a notification data map is from Stream Chat
  static bool isStreamChatMessage(Map<String, dynamic> data) {
    return data.containsKey('sender') && data['sender'] == 'stream.chat';
  }
  
  /// Parse Stream Chat notification data
  static StreamChatNotificationData parseStreamChatData(Map<String, dynamic> data) {
    return StreamChatNotificationData(
      title: data['title'] as String? ?? 'New message',
      body: data['body'] as String? ?? 'You have a new message',
      channelId: data['channel_id'] as String?,
      channelType: data['channel_type'] as String?,
      messageId: data['message_id'] as String?,
      senderId: data['receiver_id'] as String?, // Note: In Stream Chat, receiver_id is actually the mentor ID
    );
  }
  
  /// Parse general notification data
  static GeneralNotificationData parseGeneralData(Map<String, dynamic> data) {
    return GeneralNotificationData(
      title: data['title'] as String? ?? 'Notification',
      body: data['body'] as String? ?? 'You have a new notification',
      payload: data.toString(),
      eventType: data['eventType'] as String?,
    );
  }
}

/// Data class for Stream Chat notifications
class StreamChatNotificationData {
  final String title;
  final String body;
  final String? channelId;
  final String? channelType;
  final String? messageId;
  final String? senderId;
  
  const StreamChatNotificationData({
    required this.title,
    required this.body,
    this.channelId,
    this.channelType,
    this.messageId,
    this.senderId,
  });
  
  @override
  String toString() {
    return 'StreamChatNotificationData{title: $title, body: $body, channelId: $channelId}';
  }
}

/// Data class for general notifications
class GeneralNotificationData {
  final String title;
  final String body;
  final String? payload;
  final String? eventType;
  
  const GeneralNotificationData({
    required this.title,
    required this.body,
    this.payload,
    this.eventType,
  });
  
  @override
  String toString() {
    return 'GeneralNotificationData{title: $title, body: $body, eventType: $eventType}';
  }
}