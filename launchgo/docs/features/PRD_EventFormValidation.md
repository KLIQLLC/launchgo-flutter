# Event Form Validation Requirements - RND

## Overview
This document defines the requirements for time and date validation in both single and recurring event forms to ensure data integrity and prevent invalid event scheduling.

## Scope
- Single Event Form (`EventFormScreen`)
- Recurring Event Form (`RecurringEventFormScreen`)
- Date and time picker validation
- Real-time form validation
- User feedback and error handling

## Business Requirements

### Core Validation Rules

#### 1. Past Date Prevention
**Requirement**: Users must not be able to schedule events in the past
- **Rule**: Event start date/time must be in the future (after current moment)
- **Exception**: When editing existing events, allow past dates only if the event was originally scheduled in the past
- **Next Interval Rule**: Events can only be scheduled at the next available 15-minute interval (no grace period needed)

#### 2. Time Range Validation
**Requirement**: Start time must be before end time
- **Rule**: End date/time must be after start date/time
- **15-Minute Intervals**: All times must be on 15-minute intervals (enforced by dropdowns)
- **Maximum Duration**: Single events cannot exceed 24 hours
- **Cross-day Events**: Allow events that span multiple days

#### 3. Recurring Event Constraints
**Requirement**: Recurring events need additional validation
- **Rule**: Recurrence end date must be after start date
- **Maximum Range**: Recurring events cannot span more than 180 days
- **Minimum Instances**: Must create at least 2 recurring instances

## Technical Requirements

### Validation Implementation

#### Real-time Validation
```dart
// Validate as user types/selects
onDateChanged(DateTime newDate) {
  if (newDate.isBefore(DateTime.now())) {
    showError("Cannot schedule events in the past");
    resetToCurrentDate();
  }
}

onTimeChanged(TimeOfDay newTime) {
  final newDateTime = combineDateTime(selectedDate, newTime);
  if (isStartTime && newDateTime.isBefore(endDateTime)) {
    // Valid start time
  } else if (isEndTime && newDateTime.isAfter(startDateTime)) {
    // Valid end time
  } else {
    showTimeError();
  }
}
```

#### Validation Triggers
1. **Date Picker Selection**: Validate immediately when date is selected
2. **Time Picker Selection**: Validate immediately when time is selected  
3. **Form Submission**: Final validation before API call
4. **Field Focus Change**: Validate when user moves to next field

### Date Picker Constraints

#### Single Event Form
```dart
showDatePicker(
  context: context,
  initialDate: _startDate,
  firstDate: isEditMode && originalEvent.isInPast 
    ? originalEvent.startEventAt 
    : DateTime.now(),
  lastDate: DateTime.now().add(Duration(days: 180)),
);
```

#### Recurring Event Form
```dart
// Start date picker
firstDate: DateTime.now(),
lastDate: DateTime.now().add(Duration(days: 180)),

// End recurrence date picker  
firstDate: _selectedDate,
lastDate: _selectedDate.add(Duration(days: 180)),
```

### Time Selection Constraints

#### Dropdown Filtering
Instead of using native time pickers with constraints, the forms use dropdown menus with pre-filtered options:
```dart
List<String> _getAvailableTimeSlots() {
  final allSlots = TimeUtils.getTimeSlots(); // 15-minute intervals
  
  // For today, filter out past times
  if (selectedDate.isToday) {
    return allSlots.where((slot) => timeIsInFuture(slot)).toList();
  }
  
  // For future dates, show all options
  return allSlots;
}
```

#### Auto-adjustment Logic
```dart
onStartTimeChanged(TimeOfDay newStartTime) {
  if (isSameDay(startDate, endDate) && newStartTime.isAfterOrEqual(endTime)) {
    // Auto-adjust end time to be 1 hour after start
    autoAdjustEndTime(newStartTime.add(Duration(hours: 1)));
    showInfo("End time automatically adjusted");
  }
}
```

## User Experience Requirements

### Error Messages

#### Clear and Actionable
```dart
class EventValidationMessages {
  static const String pastDate = "Events cannot be scheduled in the past. Please select a future date.";
  static const String endBeforeStart = "End time must be after start time. Please adjust your times.";
  static const String maximumDuration = "Single events cannot exceed 24 hours.";
  static const String pastRecurrenceEnd = "Recurrence end date must be after the start date.";
  static const String maximumRecurrenceRange = "Recurring events cannot span more than 180 days.";
  static const String minimumRecurrenceInstances = "Recurring events must create at least 2 instances.";
}
```

#### Error Display Methods
1. **Inline Validation**: Red text below fields with specific error
2. **Snackbar**: For immediate feedback on picker selections
3. **Dialog**: For critical errors that block form submission
4. **Field Highlighting**: Red border around invalid fields

### Smart Defaults and Auto-corrections

#### Intelligent Time Suggestions
```dart
class SmartTimeDefaults {
  static TimeOfDay suggestEndTime(TimeOfDay startTime) {
    // Default to 1-hour duration on 15-minute intervals
    return startTime.add(Duration(hours: 1));
  }
  
  static DateTime suggestNextValidDateTime() {
    final now = DateTime.now();
    
    // Round up to next 15-minute interval
    return TimeUtils.nextValid15MinuteIntervalDateTime(now);
  }
}
```

#### Smart Default Behavior
1. **Form Initialization**: Start time defaults to next 15-minute interval after current time
2. **End Time Suggestion**: Automatically suggests start time + 1 hour (on 15-minute interval)
3. **Dropdown Filtering**: Only shows valid 15-minute interval times that are in the future for today's date
4. **No Auto-correction Needed**: Since dropdowns prevent invalid selections, no time corrections are necessary

### Visual Feedback

#### Time Picker Enhancements
```dart
Widget buildTimeDropdown() {
  return CupertinoDropdown(
    value: TimeUtils.formatTimeForDropdown(selectedTime),
    items: getAvailableTimeSlots(), // Pre-filtered 15-minute intervals
    onChanged: (value) => onTimeChanged(value),
  );
}
```

#### Date Picker Enhancements
```dart
Widget buildDatePicker() {
  return DatePicker(
    selectableDayPredicate: (date) => date.isAfter(DateTime.now()),
    pastDateStyle: TextStyle(color: Colors.grey[300], decoration: TextDecoration.lineThrough),
    todayHighlight: true,
  );
}
```

## Implementation Plan

### Phase 1: Core Validation Logic
```dart
class EventValidationService {
  static ValidationResult validateEventTimes({
    required DateTime startDateTime,
    required DateTime endDateTime,
    bool isEditMode = false,
    DateTime? originalStartTime,
  }) {
    // Implement all validation rules
    final errors = <String>[];
    
    // Past date validation
    if (!isEditMode && startDateTime.isBefore(DateTime.now())) {
      errors.add(EventValidationMessages.pastDate);
    }
    
    // Time range validation
    if (endDateTime.isBefore(startDateTime)) {
      errors.add(EventValidationMessages.endBeforeStart);
    }
    
    // Maximum duration validation
    if (endDateTime.difference(startDateTime) > Duration(hours: 24)) {
      errors.add(EventValidationMessages.maximumDuration);
    }
    
    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
}
```

### Phase 2: Form Integration
```dart
// Integrate validation into both forms
mixin EventFormValidation {
  List<String> validationErrors = [];
  
  void validateAndUpdateUI() {
    final result = EventValidationService.validateEventTimes(
      startDateTime: _startDateTime,
      endDateTime: _endDateTime,
      isEditMode: widget.event != null,
    );
    
    setState(() {
      validationErrors = result.errors;
    });
    
    // Show immediate feedback
    if (result.errors.isNotEmpty) {
      showValidationErrors(result.errors);
    }
  }
}
```

### Phase 3: Enhanced User Experience
- Real-time validation with debouncing
- Smart auto-corrections
- Improved visual feedback
- Accessibility improvements

## Test Cases

### Validation Test Scenarios

#### Past Date Prevention
1. ✅ **Test**: Select yesterday's date → **Expected**: Error message, date resets to today
2. ✅ **Test**: Open form when current time is 2:15 PM → **Expected**: Time dropdown shows options starting from 2:30 PM (next 15-minute interval)
3. ✅ **Test**: Edit past event → **Expected**: Allow original past date, validate new changes

#### Time Range Validation
1. ✅ **Test**: Set end time before start time → **Expected**: Error message, auto-adjust end time
2. ✅ **Test**: Set same start and end time → **Expected**: Error message, end time must be after start time
3. ✅ **Test**: Set 25-hour duration → **Expected**: Error message, maximum 24 hours

#### Recurring Event Validation
1. ✅ **Test**: Set recurrence end before start → **Expected**: Error message, auto-adjust end date
2. ✅ **Test**: Set 2-year recurrence range → **Expected**: Error message, maximum 180 days
3. ✅ **Test**: Create daily recurrence for 1 day → **Expected**: Error message, minimum 2 instances

### Edge Cases
1. **Daylight Saving Time**: Ensure validation works across DST transitions
2. **Timezone Changes**: Validate in user's local timezone
3. **Leap Year**: Handle February 29th correctly
4. **Year Boundary**: Events spanning New Year's Eve/Day

## Accessibility Requirements

### Screen Reader Support
- Validation errors announced immediately
- Clear labeling of time constraints
- Descriptive error messages

### Keyboard Navigation
- Tab order respects validation flow
- Enter key triggers validation
- Escape key cancels invalid selections

### Visual Accessibility
- High contrast error states
- Clear visual hierarchy
- Sufficient color contrast for error text

## Performance Considerations

### Validation Optimization
```dart
// Debounced validation to prevent excessive calculations
Timer? _validationTimer;

void _debouncedValidation() {
  _validationTimer?.cancel();
  _validationTimer = Timer(Duration(milliseconds: 300), () {
    validateAndUpdateUI();
  });
}
```

### Memory Management
- Dispose validation timers properly
- Avoid memory leaks in validation listeners
- Efficient error message caching

## Implementation Notes

### Platform Differences
- iOS/Android native date picker integration
- Handle platform-specific time formats
- Respect system locale settings

### Data Storage
- Store all times in UTC format
- Convert to local time for display
- Maintain timezone information for recurring events