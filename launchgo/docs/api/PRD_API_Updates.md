# API Updates PRD

## Overview
Document API changes that affect the Flutter application functionality and require implementation updates.

## API Changes

### November 13, 2025 - Event Management API Restructure

#### Breaking Changes
The event API has been restructured to separate single events and recurring events into distinct endpoints.

#### New Endpoints

##### 1. Create Single Event
**Endpoint:** `POST /api/v1/users/{userId}/events/single`
**Method:** POST
**Authentication:** Bearer Token required

**Request Body:**
```json
{
    "addressLocation": "",
    "dateAt": "2025-11-11",
    "description": "",
    "endEventAt": "2025-11-18 12:00:00Z",
    "endTime": "12:00 PM",
    "id": "",
    "latLocation": "",
    "longLocation": "",
    "name": "SIN",
    "startEventAt": "2025-11-18 11:00:00Z",
    "startTime": "13:00 PM",
    "type": "study"
}
```

**Changes from Previous API:**
- Now uses `/single` endpoint instead of generic `/events`
- User ID is now in the URL path
- New field: `dateAt` for event date
- Separate `startEventAt`/`endEventAt` with full ISO timestamps
- Separate `startTime`/`endTime` with formatted times
- Location coordinates now separate: `latLocation`, `longLocation`

##### 2. Update Single Event
**Endpoint:** `PATCH /api/v1/users/{userId}/events/{eventId}/single`
**Method:** PATCH
**Authentication:** Bearer Token required

**Request Body (Partial Updates):**
```json
{
    "name": "Updated Event Name"
}
```

**Changes from Previous API:**
- Now uses PATCH instead of PUT
- Uses `/single` endpoint with event ID
- Supports partial updates (only changed fields)

##### 3. Create Recurring Event
**Endpoint:** `POST /api/v1/users/{userId}/events/recurrence`
**Method:** POST
**Authentication:** Bearer Token required

**Request Body:**
```json
{
    "addressLocation": "",
    "dateAt": "2025-11-11",
    "description": "",
    "endEventAt": "2025-11-18 12:00:00Z",
    "endRecurrenceAt": "2025-11-20 23:59:00Z",
    "recurrenceType": "every-day",
    "endTime": "12:00 PM",
    "id": "",
    "latLocation": "",
    "longLocation": "",
    "name": "SIN",
    "startEventAt": "2025-11-18 11:00:00Z",
    "startTime": "13:00 PM",
    "type": "study"
}
```

**New Fields:**
- `endRecurrenceAt`: When the recurrence pattern ends
- `recurrenceType`: Type of recurrence (e.g., "every-day", "weekly", etc.)

##### 4. Update Recurring Event
**Endpoint:** `PATCH /api/v1/users/{userId}/events/{eventId}/recurrence`
**Method:** PATCH
**Authentication:** Bearer Token required

**Request Body (Partial Updates):**
```json
{
    "name": "Updated Recurring Event Name"
}
```

## Impact on Flutter Application

### Required Changes

#### 1. API Service Updates
- [ ] Update `ApiServiceRetrofit` to use new endpoint structure
- [ ] Separate methods for single vs recurring events
- [ ] Change from PUT to PATCH for updates
- [ ] Update URL patterns to include user ID

#### 2. Event Form Changes
- [ ] Add `dateAt` field handling
- [ ] Support separate `startEventAt`/`endEventAt` ISO timestamps
- [ ] Handle separate `startTime`/`endTime` formatted strings
- [ ] Update location fields (`latLocation`, `longLocation`)

#### 3. Recurring Event Support
- [ ] Add `endRecurrenceAt` date picker
- [ ] Add `recurrenceType` dropdown/selector
- [ ] Update recurring event form to handle new fields

#### 4. Data Model Updates
- [ ] Update `Event` model to include new fields
- [ ] Create separate models for single vs recurring events if needed
- [ ] Update JSON serialization/deserialization

### Breaking Changes Impact

#### High Priority
1. **Event Creation/Update Failing** - All event operations will fail with old endpoints
2. **Location Data** - Location coordinates now use different field names
3. **Timestamp Format** - New separate timestamp and time string fields

#### Medium Priority
1. **Recurring Events** - New recurrence fields need UI support
2. **User ID in URLs** - Need to extract user ID from auth token or user data

### Implementation Plan

#### Phase 1: Core API Updates (Critical)
1. Update API service methods for new endpoints
2. Fix event creation and update functionality
3. Update data models for new field structure

#### Phase 2: Enhanced Features
1. Implement recurring event UI
2. Add recurrence type selection
3. Update date/time handling for new format

#### Phase 3: Testing & Validation
1. Test all event CRUD operations
2. Validate location data handling
3. Test recurring event functionality

## Data Mapping

### Old vs New Field Mapping
| Old Field | New Field | Notes |
|-----------|-----------|--------|
| `startAt` | `startEventAt` + `startTime` | Split into ISO timestamp and formatted time |
| `endAt` | `endEventAt` + `endTime` | Split into ISO timestamp and formatted time |
| `addressLocation` | `addressLocation` | Unchanged |
| N/A | `latLocation` | New separate field for latitude |
| N/A | `longLocation` | New separate field for longitude |
| N/A | `dateAt` | New field for event date |
| N/A | `endRecurrenceAt` | New field for recurring events |
| N/A | `recurrenceType` | New field for recurring events |

## Implementation Status
- [ ] Update API service endpoints
- [ ] Update Event model with new fields
- [ ] Implement separate single/recurring event forms
- [ ] Add recurrence type selection UI
- [ ] Update location coordinate handling
- [ ] Test all event CRUD operations
- [x] Permission-based event access (completed)
- [x] Location permission handling (completed)

## Breaking Changes
1. **Endpoint Structure**: `/events` split into `/events/single` and `/events/recurrence`
2. **HTTP Methods**: Updates now use PATCH instead of PUT
3. **Field Names**: Location coordinates split into `latLocation`/`longLocation`
4. **Data Structure**: Times split into separate timestamp and formatted string fields
5. **URL Parameters**: User ID now required in URL path

## Migration Notes

### Immediate Actions Required
1. **Update API endpoints** in `api_service_retrofit.dart`
2. **Update Event model** to support new fields
3. **Fix event form** to handle new data structure
4. **Test event creation/update** thoroughly

### User ID Extraction
The new API requires user ID in the URL. This can be extracted from:
- JWT token claims (`mentorId` or `studentId`)
- Current user info from `AuthService`

### Backward Compatibility
- Old event data may need migration for new field structure
- Consider graceful handling of missing new fields during transition

### Testing Checklist
- [ ] Single event creation works with new endpoint
- [ ] Single event update works with PATCH method
- [ ] Recurring event creation includes all new fields
- [ ] Recurring event update works properly
- [ ] Location coordinates save/load correctly
- [ ] Date and time fields display properly
- [ ] User permissions still work with new user ID in URL
