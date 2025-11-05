import '../models/event_model.dart';

/// Helper class for event-related business logic
class EventHelper {
  /// Determines if the check-in button should be enabled for an event
  /// 
  /// Enabled when:
  /// - Status is 'check-in-required'
  /// - Current time is within check-in window (15 minutes before start to start time)
  /// 
  /// Disabled when:
  /// - Status is 'checked-in' or 'check-in-missed'
  /// - Outside the check-in time window
  static bool isCheckInEnabled(Event event) {
    // Disabled for 'checked-in' or 'check-in-missed' status
    if (event.checkInLocationStatus == 'checked-in' || 
        event.checkInLocationStatus == 'check-in-missed') {
      return false;
    }
    
    // Must be 'check-in-required' status
    if (event.checkInLocationStatus != 'check-in-required') {
      return false;
    }
    
    // Check time window: 15 minutes before start time until start time
    final now = DateTime.now();
    final eventStart = event.startAt; // Already in local time from Event.fromJson
    final checkInWindowStart = eventStart.subtract(const Duration(minutes: 15));
    
    // Enable if current time is between (start - 15 minutes) and start time
    return now.isAfter(checkInWindowStart) && now.isBefore(eventStart);
  }
  
  /// Gets the check-in window start time (15 minutes before event start)
  static DateTime getCheckInWindowStart(Event event) {
    return event.startAt.subtract(const Duration(minutes: 15));
  }
  
  /// Checks if the current time is within the check-in window
  static bool isWithinCheckInWindow(Event event) {
    final now = DateTime.now();
    final eventStart = event.startAt;
    final checkInWindowStart = getCheckInWindowStart(event);
    
    return now.isAfter(checkInWindowStart) && now.isBefore(eventStart);
  }
  
  /// Gets a human-readable status for the check-in state
  static String getCheckInStatusText(Event event) {
    switch (event.checkInLocationStatus) {
      case 'check-in-required':
        if (isWithinCheckInWindow(event)) {
          return 'Check-in available';
        } else if (DateTime.now().isBefore(getCheckInWindowStart(event))) {
          return 'Check-in opens 15 minutes before event';
        } else {
          return 'Check-in missed';
        }
      case 'checked-in':
        return 'Checked in';
      case 'check-in-missed':
        return 'Check-in missed';
      default:
        return 'No check-in required';
    }
  }
}