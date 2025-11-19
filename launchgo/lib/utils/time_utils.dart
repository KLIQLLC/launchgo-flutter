import 'package:flutter/material.dart';

/// Utility class for time-related operations and formatting
class TimeUtils {
  /// Generates time options with 15-minute intervals in AM/PM format
  /// Returns a list of strings like ["12:00 AM", "12:15 AM", ...]
  static List<String> getTimeSlots() {
    final List<String> slots = [];
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 15) {
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final period = hour < 12 ? 'AM' : 'PM';
        slots.add('${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period');
      }
    }
    return slots;
  }

  /// Formats a TimeOfDay to AM/PM string format
  /// Example: TimeOfDay(hour: 14, minute: 30) -> "02:30 PM"
  static String formatTimeForDropdown(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  /// Converts DateTime to AM/PM string format
  /// Example: DateTime with hour 14, minute 30 -> "02:30 PM"
  static String formatDateTimeForDropdown(DateTime dateTime) {
    final displayHour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    return '${displayHour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  /// Parses an AM/PM time string to TimeOfDay
  /// Example: "02:30 PM" -> TimeOfDay(hour: 14, minute: 30)
  static TimeOfDay? parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      var hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final period = parts[1];

      if (period == 'AM' && hour == 12) {
        hour = 0; // 12 AM = 0 hours
      } else if (period == 'PM' && hour != 12) {
        hour += 12; // Convert PM hours
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  /// Parses an AM/PM time string to get hour and minute in 24-hour format
  /// Returns a Map with 'hour' and 'minute' keys
  /// Example: "02:30 PM" -> {'hour': 14, 'minute': 30}
  static Map<String, int>? parseTimeStringTo24Hour(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      var hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final period = parts[1];

      // Convert to 24-hour format
      if (period == 'AM' && hour == 12) {
        hour = 0;
      } else if (period == 'PM' && hour != 12) {
        hour += 12;
      }

      return {'hour': hour, 'minute': minute};
    } catch (e) {
      return null;
    }
  }


  /// Rounds a DateTime to the nearest 15-minute interval
  static DateTime roundTo15MinuteIntervalDateTime(DateTime dateTime) {
    final totalMinutes = dateTime.hour * 60 + dateTime.minute;
    final roundedMinutes = ((totalMinutes / 15).round() * 15) % (24 * 60);
    final hours = roundedMinutes ~/ 60;
    final minutes = roundedMinutes % 60;
    
    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      hours,
      minutes,
    );
  }

  /// Gets the next 15-minute interval DateTime for smart time suggestions
  static DateTime nextValid15MinuteIntervalDateTime(DateTime dateTime) {
    final totalMinutes = dateTime.hour * 60 + dateTime.minute;
    final nextIntervalMinutes = ((totalMinutes / 15).ceil() * 15);
    
    // Handle day overflow
    if (nextIntervalMinutes >= 24 * 60) {
      return DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day + 1,
        0,
        0,
      );
    }
    
    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      nextIntervalMinutes ~/ 60,
      nextIntervalMinutes % 60,
    );
  }
}