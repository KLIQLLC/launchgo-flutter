import '../models/event_model.dart';

/// Helper class for event-related business logic and utilities
class EventHelper {
  /// Determines if the check-in button should be visible for an event 
  /// 
  /// Visible when:
  /// - Event has a location (addressLocation is not null/empty)
  /// - Event has any check-in status (check-in-required, checked-in, check-in-missed)
  /// 
  /// Hidden when:
  /// - Event has no location
  /// - No check-in status or status is null/empty
  static bool shouldShowCheckInButton(Event event) {
    // Must have location to show check-in button
    if (event.addressLocation == null || event.addressLocation!.trim().isEmpty) {
      return false;
    }
    
    // Must have a valid check-in status
    if (event.checkInLocationStatus == null || event.checkInLocationStatus!.trim().isEmpty) {
      return false;
    }
    
    // All conditions met - show check-in button
    return true;
  }

  /// Determines if the event is within the check-in timeframe
  /// 
  /// Within timeframe when:
  /// - Current time is between 15 minutes before start and end time
  /// 
  /// Outside timeframe when:
  /// - Before 15 minutes prior to start
  /// - After event end time
  static bool isWithinCheckInTimeframe(Event event) {
    final now = DateTime.now();
    final checkInStartTime = event.startAt.subtract(const Duration(minutes: 15));
    final checkInEndTime = event.endAt;
    
    return now.isAfter(checkInStartTime) && now.isBefore(checkInEndTime);
  }

  /// Determines if the check-in button should be enabled for an event
  /// 
  /// Enabled when:
  /// - Status is 'check-in-required' (server determines eligibility)
  /// - Current time is within check-in timeframe (15 mins before start to end time)
  /// 
  /// Disabled when:
  /// - Status is 'checked-in' or 'check-in-missed'
  /// - Outside timeframe (before 15 mins prior to start or after end)
  static bool isCheckInEnabled(Event event) {
    // Must have 'check-in-required' status
    if (event.checkInLocationStatus != 'check-in-required') {
      return false;
    }
    
    // Must be within timeframe
    return isWithinCheckInTimeframe(event);
  }
  
  /// Gets a human-readable status for the check-in state
  static String getCheckInStatusText(Event event) {
    switch (event.checkInLocationStatus) {
      case 'check-in-required':
        return 'Check-in available';
      case 'checked-in':
        return 'Checked in';
      case 'check-in-missed':
        return 'Check-in missed';
      default:
        return 'No check-in required';
    }
  }
}