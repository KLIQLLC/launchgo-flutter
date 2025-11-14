import 'package:flutter/material.dart';
import '../utils/event_validation_messages.dart';
import '../utils/time_utils.dart';

/// Result of event validation containing validity status and error messages
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  /// Check if there are any errors or warnings
  bool get hasIssues => errors.isNotEmpty || warnings.isNotEmpty;
}

/// Service for validating event form data
class EventValidationService {
  static const Duration _maximumSingleEventDuration = Duration(hours: 24);

  /// Validates event date and time constraints
  static ValidationResult validateEventTimes({
    required DateTime startDateTime,
    required DateTime endDateTime,
    bool isEditMode = false,
    DateTime? originalStartTime,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final now = DateTime.now();

    // Past date validation
    if (!isEditMode || (originalStartTime != null && originalStartTime.isAfter(now))) {
      if (startDateTime.isBefore(now)) {
        errors.add(EventValidationMessages.pastDate);
      }
    }

    // Time range validation - end must be after start
    if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
      errors.add(EventValidationMessages.endBeforeStart);
    }

    // Duration validation (negative handled by endBeforeStart check above)
    final duration = endDateTime.difference(startDateTime);

    // Maximum duration validation for single events
    if (duration > _maximumSingleEventDuration) {
      errors.add(EventValidationMessages.maximumDuration);
    }


    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validates recurring event constraints
  static ValidationResult validateRecurringEvent({
    required DateTime startDateTime,
    required DateTime endDateTime,
    required DateTime recurrenceEndDate,
    required String recurrenceType,
    bool isEditMode = false,
    DateTime? originalStartTime,
  }) {
    // First validate basic event times
    final basicValidation = validateEventTimes(
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      isEditMode: isEditMode,
      originalStartTime: originalStartTime,
    );

    final errors = List<String>.from(basicValidation.errors);
    final warnings = List<String>.from(basicValidation.warnings);

    // Recurrence end date must be after start date
    if (recurrenceEndDate.isBefore(startDateTime) || 
        recurrenceEndDate.isAtSameMomentAs(startDateTime)) {
      errors.add(EventValidationMessages.pastRecurrenceEnd);
    }


    // Minimum instances validation
    final estimatedInstances = _estimateRecurrenceInstances(
      startDateTime,
      recurrenceEndDate,
      recurrenceType,
    );
    if (estimatedInstances < 2) {
      errors.add(EventValidationMessages.minimumRecurrenceInstances);
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Estimates the number of recurring instances that will be created
  static int _estimateRecurrenceInstances(
    DateTime startDate,
    DateTime endDate,
    String recurrenceType,
  ) {
    final totalDays = endDate.difference(startDate).inDays;
    
    switch (recurrenceType.toLowerCase()) {
      case 'every-day':
        return totalDays + 1; // Include start day
      case 'every-week':
        return (totalDays / 7).floor() + 1;
      case 'every-month':
        // Approximate - 30 days per month
        return (totalDays / 30).floor() + 1;
      default:
        return 1;
    }
  }

  /// Suggests a valid end time based on start time
  static DateTime suggestEndTime(DateTime startDateTime) {
    return startDateTime.add(const Duration(hours: 1));
  }

  /// Suggests the next valid date/time for scheduling
  static DateTime suggestNextValidDateTime({DateTime? baseDateTime}) {
    final now = DateTime.now();
    final base = baseDateTime ?? now;
    
    // For any time in the past or present, suggest next valid 15-minute interval
    if (base.isBefore(now) || base.isAtSameMomentAs(now)) {
      return TimeUtils.nextValid15MinuteIntervalDateTime(now);
    }
    
    // For future times, ensure they're on a 15-minute interval
    return TimeUtils.roundTo15MinuteIntervalDateTime(base);
  }

  /// Suggests a valid recurrence end date
  static DateTime suggestRecurrenceEndDate(DateTime startDate) {
    return startDate.add(const Duration(days: 30));
  }

  /// Auto-corrects invalid date/time combinations
  static Map<String, DateTime> autoCorrectTimes({
    required DateTime startDateTime,
    required DateTime endDateTime,
    DateTime? recurrenceEndDate,
  }) {
    final corrections = <String, DateTime>{};
    final now = DateTime.now();
    var correctedStart = startDateTime;
    var correctedEnd = endDateTime;

    // Correct past start time
    if (startDateTime.isBefore(now)) {
      correctedStart = suggestNextValidDateTime(baseDateTime: startDateTime);
      corrections['startDateTime'] = correctedStart;
      
      // Adjust end time to maintain duration if possible
      final originalDuration = endDateTime.difference(startDateTime);
      if (originalDuration.inMinutes >= 15 && originalDuration.inHours <= 24) {
        correctedEnd = TimeUtils.roundTo15MinuteIntervalDateTime(correctedStart.add(originalDuration));
        corrections['endDateTime'] = correctedEnd;
      } else {
        correctedEnd = TimeUtils.roundTo15MinuteIntervalDateTime(suggestEndTime(correctedStart));
        corrections['endDateTime'] = correctedEnd;
      }
    }
    
    // Correct end time if before start or at same time
    if (endDateTime.isBefore(correctedStart) || 
        endDateTime.isAtSameMomentAs(correctedStart)) {
      correctedEnd = TimeUtils.roundTo15MinuteIntervalDateTime(suggestEndTime(correctedStart));
      corrections['endDateTime'] = correctedEnd;
    }

    // Correct recurrence end date if provided
    if (recurrenceEndDate != null) {
      if (recurrenceEndDate.isBefore(correctedStart)) {
        corrections['recurrenceEndDate'] = suggestRecurrenceEndDate(correctedStart);
      }
    }

    return corrections;
  }

  /// Checks if a given time is in the past
  static bool isInPast(DateTime dateTime) {
    return dateTime.isBefore(DateTime.now());
  }

  /// Gets the minimum allowed date for date pickers
  static DateTime getMinimumDate({bool isEditMode = false, DateTime? originalDate}) {
    if (isEditMode && originalDate != null && originalDate.isBefore(DateTime.now())) {
      return originalDate;
    }
    return DateTime.now();
  }

  /// Gets the maximum allowed date for date pickers
  static DateTime getMaximumDate([DateTime? baseDate]) {
    final base = baseDate ?? DateTime.now();
    return base.add(const Duration(days: 180));
  }

  /// Gets minimum allowed time for a given date
  static TimeOfDay getMinimumTime(DateTime date) {
    final now = DateTime.now();
    
    // If selecting today's date, minimum time is next 15-minute interval
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      final nextValidTime = TimeUtils.nextValid15MinuteIntervalDateTime(now);
      return TimeOfDay.fromDateTime(nextValidTime);
    }
    
    // For future dates, any time is allowed
    return const TimeOfDay(hour: 0, minute: 0);
  }

  /// Checks if a time is valid for the given date
  static bool isTimeValidForDate(DateTime date, TimeOfDay time) {
    final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    return !isInPast(dateTime);
  }
}