# Scheduling & Events - Product Requirements Document

## 1. Overview
Comprehensive scheduling system that displays events, tracks deadlines, and manages location-based check-ins for students and mentors.

## 2. User Stories

### As a Student
- I want to view my weekly schedule so I know when my events are
- I want to see upcoming assignment deadlines so I can plan my work
- I want to check in to events when I arrive at the location
- I want to receive notifications about upcoming events

### As a Mentor
- I want to view my selected student's schedule to track their activities
- I want to create and edit events for my students
- I want to monitor student check-in completion rates
- I want to see both weekly events and upcoming deadlines in one place

## 3. Functional Requirements

### FR-1: Weekly Schedule View
- **Description:** Display events in a weekly calendar format
- **Acceptance Criteria:**
  - Current week displayed by default
  - Navigation to previous/next weeks
  - Events show time, title, location, and status
  - Different visual states for different event statuses
  - Responsive design for various screen sizes

### FR-2: Event Management (Mentors Only)
- **Description:** Create, edit, and delete events for students
- **Acceptance Criteria:**
  - Create new events with date, time, location, description
  - Edit existing events with validation
  - Delete events with confirmation
  - **Delete button disabled for events that started before (current time + 15 minutes)**
  - Form validation for required fields
  - Integration with backend API

### FR-3: Location-Based Check-In (Students Only)
- **Description:** Students can check in to events when physically present
- **Acceptance Criteria:**
  - Check-in button visible only for student users
  - Check-in button hidden for mentor/case manager users
  - Check-in button hidden when event has no location set
  - Check-in button enabled only when server says `checkInLocationStatus: "check-in-required"`
  - Check-in button disabled (not hidden) outside timeframe
  - Request location permission before check-in attempt
  - Get current GPS coordinates
  - Submit coordinates to server for validation
  - Update event status based on server response
  - Handle various check-in states: required, checked-in, missed

### FR-4: Upcoming Deadlines View
- **Description:** Display assignment deadlines in chronological order
- **Acceptance Criteria:**
  - List of upcoming assignments with due dates
  - Visual indicators for overdue items
  - Course information and assignment details
  - Pull-to-refresh functionality
  - Empty state when no deadlines

### FR-5: Segmented Navigation
- **Description:** Tab-based switching between schedule and deadline views
- **Acceptance Criteria:**
  - Two tabs: "Weekly Schedule" and "Upcoming Deadlines"
  - Smooth transition between tabs
  - Maintain state when switching tabs
  - Visual indication of active tab

## 4. Technical Requirements

### TR-1: Data Management
- Efficient API calls with caching
- Offline support for recently viewed data
- Real-time updates when data changes
- UTC time handling with local display

### TR-2: Location Services
- Request location permissions with clear explanation
- Handle permission denied scenarios gracefully
- Accurate GPS coordinate capture
- Battery-efficient location requests

### TR-3: Performance
- Smooth scrolling in weekly view
- Fast tab switching (< 100ms)
- Efficient date calculations
- Memory-efficient event rendering

## 5. User Interface Requirements

### UI-1: Weekly Schedule View
- Clean, calendar-like interface
- Color-coded events by type/status
- Clear time indicators
- Event cards with essential information
- Week navigation controls

### UI-2: Event Cards
- Event title and time prominently displayed
- Location information when relevant
- Check-in button with appropriate state (students only)
- Check-in button hidden when no location is set for the event
- Check-in button hidden for mentor/case manager users
- **Delete/swipe-to-delete/tap-to-edit/view disabled for events that started before (current time + 15 minutes)**
- **Example: If current time is 15:00, disable delete for events that started before 15:15**
- **Disabled buttons shown in grayed-out state with reduced opacity**

#### Event Interaction Restrictions:
**Example at 15:00:**
- ❌ **Cannot interact**: Events starting before 15:15 (no delete, swipe-to-delete, edit, or view)
- ✅ **Can interact**: Events starting at 15:15 or later (all actions available)

**Logic**: `event.startEventAt < (DateTime.now() + Duration(minutes: 15))`
- Visual status indicators (checked-in, missed, etc.)
- Tap to view details

### UI-3: Deadline Cards
- Assignment title and course
- Due date with time remaining
- Visual urgency indicators
- Course color coding
- Progress indicators if available

### UI-4: Check-In Flow
- Loading states during location acquisition
- Clear success/failure messages
- Permission request explanations
- Error recovery options

## 6. Edge Cases & Error Scenarios

### EC-1: Location Permission Denied
- **Scenario:** User denies location permission for check-in
- **Behavior:** Show explanation dialog with option to open settings

### EC-2: Location Service Disabled
- **Scenario:** Device location services are turned off
- **Behavior:** Prompt user to enable location services with direct settings link

### EC-3: GPS Accuracy Issues
- **Scenario:** GPS coordinates are inaccurate or unavailable
- **Behavior:** Show retry option and inform user about location requirements

### EC-6: Check-In at Wrong Location
- **Scenario:** Student attempts to check in while not at event location
- **Behavior:** 
  - App sends current GPS coordinates to server
  - Server validates location against event address
  - If out of range: Show "Check-in failed: You may be out of range" message
  - Check-in status remains "check-in-required" for retry
  - If within range: Show "Successfully checked in!" message and update status to "checked-in"

### EC-4: Network Issues During Check-In
- **Scenario:** No internet during check-in attempt
- **Behavior:** Queue check-in for retry when connection restored

### EC-5: Event Time Changes
- **Scenario:** Event time modified while user is viewing
- **Behavior:** Refresh view and show notification of changes

## 7. Location & Permission Requirements

### Geolocation Features
- Request "When In Use" location permission
- Explain why location is needed before requesting
- Graceful fallback when location unavailable
- Respect user privacy preferences

### Permission Flow (Students Only)
1. Student user taps check-in button (only visible for students with location-enabled events)
2. Check if location permission granted
3. If not granted, show explanation dialog
4. Request permission with system dialog
5. If denied, guide user to settings
6. If granted, proceed with location acquisition

### Check-In Button Visibility Rules
- **Hidden for:** Mentor/Case Manager users (all events)
- **Hidden for:** Events without location information
- **Visible for:** Student users on events with location and valid check-in status
- **Disabled (not hidden) for:** Events outside timeframe (before 15 mins prior to start or after end time)

### Check-In Button Enabled Timeframe
- **Enabled:** 15 minutes before event start time until event end time
- **Disabled:** Before 15-minute window or after event has ended
- **Purpose:** Ensures students can only check in when they should reasonably be present

## 8. Data Models

### Event Model
```dart
class Event {
  String id;
  String title;
  DateTime startAt;
  DateTime endAt;
  String location;
  String checkInLocationStatus; // 'check-in-required', 'checked-in', 'check-in-missed'
  Color color;
}
```

### Deadline Model
```dart
class DeadlineAssignment {
  String id;
  String title;
  String courseTitle;
  DateTime dueDate;
  String status;
}
```

## 9. Success Metrics

- Check-in completion rate > 80%
- Schedule view engagement > 5 minutes/session
- Event navigation accuracy > 95%
- Location permission grant rate > 70%

## 10. Dependencies

- **Location Services:** geolocator package
- **Permissions:** permission_handler package
- **Date/Time:** intl package for formatting
- **State Management:** Provider for schedule state

---

**Priority:** Must Have (MVP)  
**Effort Estimate:** 4-5 weeks  
**Risk Level:** Medium (location permissions, GPS accuracy)