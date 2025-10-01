import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:intl/intl.dart';

/// Custom message widget with custom background colors and styling
class CustomMessageWidget extends StatelessWidget {
  final Message message;
  final MessageDetails details;
  final List<Message> messages;
  
  const CustomMessageWidget({
    super.key,
    required this.message,
    required this.details,
    required this.messages,
  });
  
  @override
  Widget build(BuildContext context) {
    final isMyMessage = details.isMyMessage;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: isMyMessage 
          ? MainAxisAlignment.end 
          : MainAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMyMessage 
                ? CrossAxisAlignment.end 
                : CrossAxisAlignment.start,
              children: [
                if (!isMyMessage)
                  _buildUsername(),
                _buildMessageBubble(context, isMyMessage),
                _buildTimestamp(),
              ],
            ),
          ),
          if (isMyMessage) ...[
            const SizedBox(width: 8),
            _buildAvatar(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildAvatar() {
    final user = message.user;
    return CircleAvatar(
      radius: 16,
      backgroundImage: user?.image != null 
        ? NetworkImage(user!.image!) 
        : null,
      backgroundColor: const Color(0xFF2A3441),
      child: user?.image == null 
        ? Text(
            user?.name.substring(0, 1).toUpperCase() ?? '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          )
        : null,
    );
  }
  
  Widget _buildUsername() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        message.user?.name ?? 'Unknown',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  Widget _buildMessageBubble(BuildContext context, bool isMyMessage) {
    // Custom background colors
    final backgroundColor = isMyMessage
      ? const Color(0xFFF8FAFC) // Light background for own messages
      : const Color(0xFF1A2332); // Dark card color for others
    
    // Custom text colors
    final textColor = isMyMessage
      ? const Color(0xFF0E172A) // Dark blue text for own messages
      : Colors.white; // White text on dark background
    
    // Custom border radius
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMyMessage 
        ? const Radius.circular(16) 
        : const Radius.circular(4),
      bottomRight: isMyMessage 
        ? const Radius.circular(4) 
        : const Radius.circular(16),
    );
    
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message text
          if (message.text?.isNotEmpty == true)
            Text(
              message.text!,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          
          // Attachments (images, files, etc.)
          if (message.attachments.isNotEmpty)
            ...message.attachments.map((attachment) {
              if (attachment.type == 'image') {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      attachment.imageUrl ?? attachment.assetUrl ?? '',
                      width: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) {
                        return Container(
                          width: 200,
                          height: 100,
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
        ],
      ),
    );
  }
  
  Widget _buildTimestamp() {
    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());
    
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            time,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
          // Show read status for sent messages
          if (details.isMyMessage)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.done_all,
                size: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }
}

/// Example of gradient message backgrounds
class GradientMessageWidget extends StatelessWidget {
  final Message message;
  final bool isMyMessage;
  
  const GradientMessageWidget({
    super.key,
    required this.message,
    required this.isMyMessage,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isMyMessage
            ? [
                const Color(0xFFF8FAFC),
                const Color(0xFFE2E8F0),
              ]
            : [
                const Color(0xFF1A2332),
                const Color(0xFF252F3F),
              ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message.text ?? '',
        style: TextStyle(
          color: isMyMessage ? const Color(0xFF0E172A) : Colors.white,
          fontSize: 15,
        ),
      ),
    );
  }
}