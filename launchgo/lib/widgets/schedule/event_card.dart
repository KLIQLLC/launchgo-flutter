import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/event_model.dart';
import '../../services/api_service_retrofit.dart';
import '../../services/auth_service.dart';
import '../../utils/event_helper.dart';
import '../swipeable_card.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onView;
  final Function(Event)? onEventUpdated;

  const EventCard({
    super.key,
    required this.event,
    this.onEdit,
    this.onDelete,
    this.onView,
    this.onEventUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final bool canDelete = onDelete != null && EventHelper.canDeleteEvent(event);
    final bool canEdit = onEdit != null && EventHelper.canDeleteEvent(event);
    final bool canView = onView != null; // View is always enabled if callback provided
    
    // Determine the tap action: edit if available and allowed, otherwise view
    final VoidCallback? tapAction;
    if (canEdit) {
      tapAction = onEdit;
    } else if (canView) {
      tapAction = onView;
    } else {
      tapAction = null;
    }
    
    return SwipeableCard(
      canSwipe: canDelete,
      canTap: tapAction != null,
      onTap: tapAction,
      onSwipeToDelete: canDelete ? () => _handleSwipeToDelete(context) : null,
      deleteIcon: Icons.delete,
      child: _EventCardContent(event: event, onEventUpdated: onEventUpdated),
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
  final Function(Event)? onEventUpdated;

  const _EventCardContent({required this.event, this.onEventUpdated});

  bool get _isMissedCheckIn =>
      event.checkInLocationStatus?.trim().toLowerCase() == 'check-in-missed';

  Future<void> _handleCheckIn(BuildContext context) async {
    // 1. Check if location services are enabled
    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    // 2. Permission
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      if (context.mounted) {
        await _showLocationPermissionDialog(context);
      }
      return;
    }

    if (status.isGranted) {
      try {
        // Show loading indicator
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Getting location and checking in...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ));
        }

        // Get current position
        Position pos = await Geolocator.getCurrentPosition();
        
        // Get API service and user ID
        final apiService = context.mounted ? context.read<ApiServiceRetrofit>() : null;
        final authService = context.mounted ? context.read<AuthService>() : null;
        final userId = authService?.userInfo?.id;

        if (userId == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('User not authenticated'),
              backgroundColor: Colors.red,
            ));
          }
          return;
        }

        if (apiService == null) {
          return; // Context no longer valid
        }

        // Prepare location data
        final locationData = {
          'latLocation': pos.latitude.toString(),
          'longLocation': pos.longitude.toString(),
        };

        // Call check-in API
        final response = await apiService.checkInEvent(userId, event.id, locationData);

        if (response != null && context.mounted) {
          // Update the event with the response data (contains updated checkInLocationStatus)
          final updatedEvent = Event.fromJson(response);
          onEventUpdated?.call(updatedEvent);
          
          // Check if check-in was actually successful based on the status
          if (updatedEvent.checkInLocationStatus == 'checked-in') {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Successfully checked in!'),
              backgroundColor: Colors.green,
            ));
          } else {
            // Check-in failed (status is still 'check-in-required' or other)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Check-in failed: You may be out of range'),
              backgroundColor: Colors.red,
            ));
          }
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Check-in failed'),
            backgroundColor: Colors.red,
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Check-in failed: $e'),
            backgroundColor: Colors.red,
          ));
        }
      }
    }
  }

  Future<void> _showLocationPermissionDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'To check in to this event, we need access to your device location to verify you are at the correct location.\n\n'
            'Would you like to open Settings to enable location access?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );

    // Only open settings if user confirmed
    if (result == true) {
      if (context.mounted) {
        await openAppSettings();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enable location access in Settings, then try checking in again.'),
          backgroundColor: Colors.orange,
        ));
      }
    }
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
        width: _isMissedCheckIn ? 2.0 : 1.0,
      ),
    );
  }

  Color get _cardFillColor => Color.alphaBlend(event.color.withValues(alpha: 0.15), const Color(0xFF1A2332));

  @override
  Widget build(BuildContext context) {
    final isStudent = context.watch<AuthService>().isStudent;
    final checkInColor = event.color;
    final bool checkInEnabled = EventHelper.isCheckInEnabled(event);
    final bool shouldShowCheckIn = EventHelper.shouldShowCheckInButton(event);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _EventTitle(event: event)),
              if (event.addressLocation != null && event.addressLocation!.isNotEmpty)
                SvgPicture.asset(
                  'assets/icons/ic_marker.svg',
                  width: 16,
                  height: 16,
                  colorFilter: ColorFilter.mode(
                    event.color,
                    BlendMode.srcIn,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          _EventTime(event: event),
          if (isStudent && shouldShowCheckIn)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: checkInEnabled
                  ? ElevatedButton(
                      onPressed: () => _handleCheckIn(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A2332),
                        side: BorderSide(color: event.color.withValues(alpha: 0.4), width: 0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, color: checkInColor),
                          const SizedBox(width: 12),
                          Text('Check In', style: TextStyle(color: checkInColor, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: _cardFillColor,
                        border: Border.all(color: event.color.withValues(alpha: 0.4), width: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, color: checkInColor.withValues(alpha: 0.5)),
                          const SizedBox(width: 12),
                          Text('Check In', style: TextStyle(color: checkInColor.withValues(alpha: 0.5), fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
              ),
            ),
        ],
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

