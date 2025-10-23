# Push Notification Navigation Guide

## Overview
The app uses `PushNavigationService` to handle navigation from push notifications in all app states (foreground, background, terminated).

## Architecture
- **PushNotificationService**: Handles FCM setup and notification receipt
- **PushNavigationService**: Handles navigation logic based on notification payloads
- **go_router**: Provides the navigation framework

## Notification Payload Formats

### 1. Stream Chat Notifications (Automatic)
Stream Chat notifications include these fields automatically:
```json
{
  "channel_id": "user123",
  "channel_type": "messaging",
  "channel_cid": "messaging:user123",
  "message": "New message text"
}
```

### 2. Navigate by Screen Name
Use the `screen` field to navigate to predefined screens:
```json
{
  "notification": {
    "title": "New Assignment",
    "body": "You have a new assignment to complete"
  },
  "data": {
    "screen": "schedule"
  }
}
```

Supported screens:
- `chat` - Opens chat screen
- `schedule` - Opens schedule screen
- `courses` - Opens courses list
- `documents` - Opens documents list
- `recaps` - Opens recaps (mentors only)
- `assignments` - Opens assignments (with optional `course_id`)
- `notifications` - Opens notifications list
- `settings` - Opens settings

### 3. Navigate by Route Path
Use the `route` field for specific route navigation:
```json
{
  "notification": {
    "title": "Course Updated",
    "body": "Introduction to Programming has been updated"
  },
  "data": {
    "route": "/courses"
  }
}
```

### 4. Navigate with Extra Data
Pass additional data using route and extra fields:
```json
{
  "notification": {
    "title": "Assignment Due",
    "body": "Your assignment is due tomorrow"
  },
  "data": {
    "screen": "assignments",
    "course_id": "course123"
  }
}
```

## Backend Examples

### Firebase Admin SDK (Node.js)
```javascript
const message = {
  notification: {
    title: 'New Chat Message',
    body: 'John: Hello there!'
  },
  data: {
    screen: 'chat',
    channel_id: 'user123',
    channel_type: 'messaging'
  },
  token: userFcmToken
};

admin.messaging().send(message);
```

### Firebase Console Testing
1. Go to Firebase Console > Cloud Messaging
2. Click "New notification"
3. Add notification title and text
4. Under "Additional options" > "Custom data", add:
   - Key: `screen`, Value: `chat`
   - Key: `channel_id`, Value: `test123` (optional)

### cURL Example
```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "FCM_TOKEN",
    "notification": {
      "title": "Test Notification",
      "body": "Testing navigation"
    },
    "data": {
      "screen": "schedule"
    }
  }'
```

## Navigation Behavior

### App in Foreground
- Notification appears as banner/toast
- Tapping navigates to specified screen
- Current screen state may be preserved

### App in Background
- System notification appears
- Tapping brings app to foreground
- Navigates to specified screen

### App Terminated
- System notification appears
- Tapping launches app
- After initialization, navigates to specified screen (with 500ms delay)

## Testing Push Navigation

### 1. Test Basic Navigation
Send a notification with:
```json
{
  "data": {
    "screen": "schedule"
  }
}
```

### 2. Test Chat Navigation
Send a notification with:
```json
{
  "data": {
    "screen": "chat",
    "channel_id": "test_channel"
  }
}
```

### 3. Test Deep Link
Send a notification with:
```json
{
  "data": {
    "route": "/course/123/assignments"
  }
}
```

## Debugging

Enable debug logs to see navigation flow:
1. Check console for `🧭` prefixed messages from PushNavigationService
2. Check console for `🔔` prefixed messages from PushNotificationService

Common issues:
- **Navigation not working**: Ensure router is initialized before handling notifications
- **Wrong screen opens**: Check payload format and screen name spelling
- **Crash on navigation**: Verify route exists in router configuration

## Adding New Navigation Targets

To add a new navigation target:

1. Add route to `app_router.dart`:
```dart
GoRoute(
  path: '/new-feature',
  name: 'newFeature',
  builder: (context, state) => NewFeatureScreen(),
)
```

2. Add case to `PushNavigationService._navigateToScreen()`:
```dart
case 'new_feature':
  _router!.go('/new-feature');
  break;
```

3. Send notification with:
```json
{
  "data": {
    "screen": "new_feature"
  }
}
```