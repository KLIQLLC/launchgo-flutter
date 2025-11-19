import 'dart:async';
import 'package:flutter/material.dart';
import '../services/event_validation_service.dart';
import '../utils/event_validation_messages.dart';

/// Mixin for event form validation functionality
mixin EventFormValidationMixin<T extends StatefulWidget> on State<T> {
  /// Current validation errors
  List<String> validationErrors = [];
  
  /// Current validation warnings
  List<String> validationWarnings = [];
  
  /// Timer for debounced validation
  Timer? _validationTimer;
  
  /// Whether validation is currently in progress
  bool _isValidating = false;

  @override
  void dispose() {
    _validationTimer?.cancel();
    super.dispose();
  }

  /// Validates event times with debouncing
  void validateEventTimes({
    required DateTime startDateTime,
    required DateTime endDateTime,
    DateTime? recurrenceEndDate,
    String? recurrenceType,
    bool isEditMode = false,
    DateTime? originalStartTime,
    bool immediate = false,
  }) {
    if (_isValidating && !immediate) return;

    _validationTimer?.cancel();
    
    if (immediate) {
      _performValidation(
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        recurrenceEndDate: recurrenceEndDate,
        recurrenceType: recurrenceType,
        isEditMode: isEditMode,
        originalStartTime: originalStartTime,
      );
    } else {
      _validationTimer = Timer(const Duration(milliseconds: 300), () {
        _performValidation(
          startDateTime: startDateTime,
          endDateTime: endDateTime,
          recurrenceEndDate: recurrenceEndDate,
          recurrenceType: recurrenceType,
          isEditMode: isEditMode,
          originalStartTime: originalStartTime,
        );
      });
    }
  }

  /// Performs the actual validation
  void _performValidation({
    required DateTime startDateTime,
    required DateTime endDateTime,
    DateTime? recurrenceEndDate,
    String? recurrenceType,
    bool isEditMode = false,
    DateTime? originalStartTime,
  }) {
    if (!mounted) return;
    
    _isValidating = true;

    ValidationResult result;
    
    if (recurrenceEndDate != null && recurrenceType != null) {
      // Validate recurring event
      result = EventValidationService.validateRecurringEvent(
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        recurrenceEndDate: recurrenceEndDate,
        recurrenceType: recurrenceType,
        isEditMode: isEditMode,
        originalStartTime: originalStartTime,
      );
    } else {
      // Validate single event
      result = EventValidationService.validateEventTimes(
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        isEditMode: isEditMode,
        originalStartTime: originalStartTime,
      );
    }

    if (mounted) {
      setState(() {
        validationErrors = result.errors;
        validationWarnings = result.warnings;
      });

      // Show immediate feedback for errors
      if (result.errors.isNotEmpty) {
        _showValidationFeedback(result.errors, isError: true);
      } else if (result.warnings.isNotEmpty) {
        _showValidationFeedback(result.warnings, isError: false);
      }
    }

    _isValidating = false;
  }

  /// Shows validation feedback to the user
  void _showValidationFeedback(List<String> messages, {required bool isError}) {
    if (!mounted || messages.isEmpty) return;

    final message = messages.first; // Show first error/warning
    final color = isError ? Colors.red : Colors.orange;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: isError ? 4 : 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Auto-corrects invalid times and shows user feedback
  Map<String, DateTime> autoCorrectTimes({
    required DateTime startDateTime,
    required DateTime endDateTime,
    DateTime? recurrenceEndDate,
  }) {
    final corrections = EventValidationService.autoCorrectTimes(
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      recurrenceEndDate: recurrenceEndDate,
    );

    // Auto-corrections happen silently since UI prevents invalid selections

    return corrections;
  }

  /// Checks if form can be submitted
  bool canSubmitForm() {
    return validationErrors.isEmpty;
  }

  /// Gets error message for a specific field
  String? getFieldError(String fieldName) {
    // Map validation errors to specific fields
    for (final error in validationErrors) {
      if (error.contains('past') && fieldName == 'date') {
        return error;
      }
      if (error.contains('End time') && fieldName == 'endTime') {
        return error;
      }
      if (error.contains('15 minutes') && (fieldName == 'startTime' || fieldName == 'endTime')) {
        return error;
      }
      if (error.contains('24 hours') && fieldName == 'duration') {
        return error;
      }
      if (error.contains('Recurrence') && fieldName == 'recurrenceEnd') {
        return error;
      }
    }
    return null;
  }

  /// Shows field-specific error styling
  InputDecoration getFieldDecoration({
    required InputDecoration baseDecoration,
    required String fieldName,
  }) {
    final error = getFieldError(fieldName);
    if (error != null) {
      return baseDecoration.copyWith(
        errorText: error,
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
      );
    }
    return baseDecoration;
  }

  /// Gets time picker constraints for a given date
  TimeOfDay? getMinimumTimeForDate(DateTime date, {bool isEditMode = false}) {
    if (!isEditMode || !EventValidationService.isInPast(date)) {
      return EventValidationService.getMinimumTime(date);
    }
    return null;
  }

  /// Gets date picker constraints
  DateTimeRange getDateConstraints({bool isEditMode = false, DateTime? originalDate}) {
    return DateTimeRange(
      start: EventValidationService.getMinimumDate(
        isEditMode: isEditMode,
        originalDate: originalDate,
      ),
      end: EventValidationService.getMaximumDate(),
    );
  }

  /// Smart time suggestion when user selects start time
  DateTime suggestEndTimeForStart(DateTime startDateTime) {
    return EventValidationService.suggestEndTime(startDateTime);
  }

  /// Smart date/time suggestion for new events
  DateTime suggestNextValidDateTime() {
    return EventValidationService.suggestNextValidDateTime();
  }
}