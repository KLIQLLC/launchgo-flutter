import '../models/event_model.dart';

/// Helper class for event-related business logic
class EventHelper {
  /// Determines if the check-in button should be enabled for an event
  /// 
  /// Enabled when:
  /// - Status is 'check-in-required' (server determines eligibility)
  /// 
  /// Disabled when:
  /// - Status is 'checked-in' or 'check-in-missed'
  static bool isCheckInEnabled(Event event) {
    // Only enabled for 'check-in-required' status - server controls the eligibility
    return event.checkInLocationStatus == 'check-in-required';
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