import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../services/api_service_retrofit.dart';
import '../swipeable_card.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const EventCard({
    super.key,
    required this.event,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SwipeableCard(
      canSwipe: onDelete != null,
      canTap: onEdit != null,
      onTap: onEdit,
      onSwipeToDelete: onDelete != null ? () => _handleSwipeToDelete(context) : null,
      deleteIcon: Icons.delete,
      child: _EventCardContent(event: event),
    );
  }

  Future<bool> _handleSwipeToDelete(BuildContext context) async {
    final confirmed = await _showDeleteConfirmation(context);
    if (confirmed == true && context.mounted) {
      await _deleteEvent(context);
      return true;
    }
    return false;
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2332),
          title: const Text(
            'Delete Event',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete "${event.name}"?',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteEvent(BuildContext context) async {
    try {
      final apiService = context.read<ApiServiceRetrofit>();
      await apiService.deleteEvent(event.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
          ),
        );
        
        // Call the onDelete callback to notify parent widget
        onDelete?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete event: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}

class _EventCardContent extends StatelessWidget {
  final Event event;

  const _EventCardContent({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EventTitle(event: event),
          const SizedBox(height: 4),
          _EventTime(event: event),
          if (event.location != null && event.location!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _EventLocation(event: event),
          ],
        ],
      ),
    );
  }

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: Color.alphaBlend(
        event.color.withValues(alpha: 0.15),
        const Color(0xFF1A2332),
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: event.color.withValues(alpha: 0.4),
        width: 1.0,
      ),
    );
  }
}

class _EventTitle extends StatelessWidget {
  final Event event;

  const _EventTitle({required this.event});

  @override
  Widget build(BuildContext context) {
    return Text(
      event.name,
      style: TextStyle(
        color: event.color,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EventTime extends StatelessWidget {
  final Event event;

  const _EventTime({required this.event});

  @override
  Widget build(BuildContext context) {
    return Text(
      event.displayTime,
      style: TextStyle(
        color: event.color.withValues(alpha: 0.8),
        fontSize: 14,
      ),
    );
  }
}

class _EventLocation extends StatelessWidget {
  final Event event;

  const _EventLocation({required this.event});

  @override
  Widget build(BuildContext context) {
    return Text(
      event.location!,
      style: TextStyle(
        color: event.color.withValues(alpha: 0.8),
        fontSize: 14,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}