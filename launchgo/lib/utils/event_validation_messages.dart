/// Event validation error messages
class EventValidationMessages {
  static const String pastDate = "Events cannot be scheduled in the past. Please select a future date.";
  static const String endBeforeStart = "End time must be after start time. Please adjust your times.";
  static const String maximumDuration = "Single events cannot exceed 24 hours.";
  static const String pastRecurrenceEnd = "Recurrence end date must be after the start date.";
  static const String minimumRecurrenceInstances = "Recurring events must create at least 2 instances.";
  
}