# Video Call - Product Requirements Document

## 1. Overview
Real-time video calling system using [Stream Video](https://getstream.io/video/) that enables mentors to initiate video calls with their students. Only mentors can call; students can receive and respond to incoming calls.

## 2. User Stories

### As a Mentor
- I want to initiate a video call with my selected student so I can provide face-to-face guidance
- I want to see when my student has joined the call
- I want to control my camera and microphone during the call
- I want to end the call when our session is complete

### As a Student
- I want to see the native phone call UI (like regular calls) when receiving a video call
- I want to accept or decline incoming video calls from the lock screen
- I want to see my mentor during an active call
- I want to control my camera and microphone during the call
- I want to end the call when needed

## 3. Functional Requirements

### FR-1: Call Initiation (Mentor Only)
- **Description:** Mentors can initiate video calls to their selected student
- **Acceptance Criteria:**
  - Call button available only for mentor role
  - Call button visible only when a student is selected
  - Tapping call button initiates outgoing call to selected student
  - Student receives incoming call notification
  - Mentor sees "Connecting..." state while waiting for student

### FR-2: Incoming Call Handling (Student Only)
- **Description:** Students receive and respond to incoming calls
- **Acceptance Criteria:**
  - Incoming call screen displays automatically when call arrives
  - Shows caller (mentor) name
  - Accept button joins the call
  - Decline button rejects the call and notifies mentor
  - Request camera and microphone permissions before joining
  - Fallback to settings if permissions denied

### FR-2.1: Background & Terminated App Call Reception (Student Only)
- **Description:** Students can receive calls even when app is backgrounded or terminated
- **Acceptance Criteria:**
  - **iOS:** Native CallKit UI appears for incoming calls (like regular phone calls)
  - **Android:** High-priority notification wakes device and shows full-screen incoming call UI
  - Works when app is in background or completely terminated
  - **IMPORTANT:** Native CallKit UI should **NOT** be displayed when app is in foreground - use custom in-app UI instead
  - Accepting call launches app (if terminated) and connects to call
  - Accepting call via CallKit should navigate directly to video call screen WITHOUT showing in-app incoming call UI again (no double-accept)
  - Declining call notifies mentor without launching app
  - Call rings for configurable timeout (e.g., 30-60 seconds) before auto-decline

### FR-3: Active Call Experience
- **Description:** Full-featured video call interface for both participants
- **Acceptance Criteria:**
  - Video streams from both participants displayed
  - Microphone mute/unmute toggle
  - Camera on/off toggle
  - End call button prominently displayed
  - Call status indicator (Connecting, Connected, Waiting for participant)
  - Screen stays awake during call
  - Participant name displayed in header

### FR-4: Call Termination
- **Description:** Either party can end the call at any time
- **Acceptance Criteria:**
  - End call button immediately terminates the call
  - Both participants notified when call ends
  - User returned to previous screen after call ends
  - Proper cleanup of call resources

### FR-5: Call State Management
- **Description:** Proper handling of call lifecycle and edge cases
- **Acceptance Criteria:**
  - Only one active call at a time
  - Stale calls cleaned up before new call creation
  - App handles call state across navigation
  - Proper reconnection handling for network issues

## 4. Technical Requirements

### TR-1: Stream Video SDK Integration
- Stream Video Flutter SDK (`stream_video_flutter`)
- Separate API key configuration for video service
- Separate token from chat (`callGetStreamToken`)
- Proper SDK initialization with user credentials

### TR-2: Token Management
- JWT tokens for Stream Video authentication
- **`callGetStreamToken` is unique per user** - each user has their own token containing their `user_id` claim
- Token must match the `userId` passed to `User.regular()` or authentication fails
- Backend generates token signed with Stream Video secret key for each authenticated user
- Token expiration validation before initialization
- Separate token storage from chat tokens (`callGetStreamToken` vs `chatGetStreamToken`)
- Token refresh handling for expired sessions
- On logout, `StreamVideoService.disconnect()` must be called to reset state for next user

### TR-3: Platform Configuration

#### iOS
- Camera usage description in Info.plist (`NSCameraUsageDescription`)
- Microphone usage description in Info.plist (`NSMicrophoneUsageDescription`)
- VoIP usage description in Info.plist (`NSVoIPUsageDescription`) - Required for CallKit
- Background modes in Info.plist (`UIBackgroundModes`): `voip`, `audio`, `fetch`, `remote-notification`
- Push notification entitlements: APS Environment (development/production)
- VoIP Push entitlement enabled in Apple Developer Portal
- VoIP Services Certificate configured in Apple Developer Portal

#### Android
- Camera permission in AndroidManifest.xml
- Microphone permission in AndroidManifest.xml
- `USE_FULL_SCREEN_INTENT` permission for lock screen incoming call UI
- `FOREGROUND_SERVICE` permission for ongoing calls
- `WAKE_LOCK` permission to wake device for incoming calls
- `VIBRATE` permission for call notifications
- `SYSTEM_ALERT_WINDOW` permission (for overlay on some devices)

### TR-3.1: VoIP Push Notifications (Required for Background/Terminated Calls)

#### iOS - CallKit + VoIP Push
- **VoIP Push Certificate:** Separate APNs VoIP certificate (not regular push)
- **CallKit Integration:** Native iOS call UI via `flutter_callkit_incoming` or Stream SDK CallKit support
- **PushKit:** Register for VoIP pushes using PushKit framework
- **Token Registration:** Send VoIP device token to backend/Stream
- **Payload Requirements:** VoIP push must include call metadata (caller name, call ID)
- **App Launch:** iOS automatically launches app in background when VoIP push received

#### Android - FCM High-Priority + ConnectionService
- **FCM Data Message:** High-priority (`priority: high`) data-only message
- **Full-Screen Intent:** Show incoming call UI even on lock screen
- **ConnectionService:** Optional system-level call management (like CallKit)
- **Foreground Service:** Required for processing push when app terminated
- **Wake Lock:** Acquire wake lock to process incoming call
- **Notification Channel:** Dedicated high-importance channel for calls

#### Backend Requirements
- Stream Video must be configured to send VoIP pushes
- Backend must register device tokens with Stream for each user
- VoIP push credentials must be uploaded to Stream Dashboard:
  - iOS: APNs VoIP certificate (.p12 or .p8)
  - Android: Firebase service account JSON

### TR-4: Permissions Handling
- Runtime permission requests for camera and microphone
- Permission status checking before call actions
- Settings redirect for permanently denied permissions
- Graceful degradation (audio-only if camera denied)

### TR-5: Performance
- Efficient video rendering using SDK components
- Wakelock to prevent screen sleep during calls
- Proper resource cleanup on call end
- Memory management for video streams

### TR-6: App Wake-up & Call Joining (Terminated App)
When app receives incoming call while terminated/closed:
1. **Push notification wakes the app** - VoIP push (iOS) or FCM high-priority (Android)
2. **StreamVideoService must initialize** - Service was not running, needs fresh initialization with user's `callGetStreamToken`
3. **Call ID passed from push payload** - Since `_incomingCall` object is null (no active listener), the call ID from push is required
4. **Fetch call by ID** - Use `client.makeCall()` + `call.getOrCreate()` to retrieve the existing call
5. **Accept and join** - Call `call.accept()` then `call.join()` to connect
6. **Handle race conditions** - User may have re-authenticated, ensure correct token is used

**Implementation in `acceptIncomingCall()`:**
- Accepts optional `callId` parameter for terminated app scenario
- If `_incomingCall` is null but `callId` provided, fetches call by ID
- Ensures both foreground and terminated app flows work correctly

## 5. User Interface Requirements

### UI-1: Call Initiation Button
- Phone/video icon button in chat header or student profile
- Disabled state when no student selected (for mentors)
- Loading state while initiating call
- Only visible to mentor role

### UI-2: Incoming Call Screen
- Full-screen overlay with dark background
- Caller avatar placeholder with person icon
- Caller name prominently displayed
- "Incoming video call" status text
- Green accept button with videocam icon
- Red decline button with call_end icon
- Button labels ("Accept", "Decline")

### UI-3: Active Call Screen
- Full-screen video display
- Participant grid layout from Stream SDK
- Top gradient overlay with:
  - Recipient name
  - Call status (Connecting/Connected/Waiting)
- Bottom gradient overlay with controls:
  - Microphone toggle (mic/mic_off icons)
  - End call button (red, centered, prominent)
  - Camera toggle (videocam/videocam_off icons)
- Safe area padding for notches and home indicators

### UI-4: Call Controls
- Circular button design
- Active/inactive visual states for toggles
- White icons on semi-transparent backgrounds
- Red background for end call button

## 6. Role-Based Access Control

### Mentor Capabilities
- Initialize video service on authentication
- Create and initiate outgoing calls
- Join created calls automatically
- End active calls
- NO incoming call handling (mentors don't receive calls)

### Student Capabilities
- Initialize video service on authentication
- Listen for incoming calls automatically
- Accept or decline incoming calls
- Join accepted calls
- End active calls
- NO call initiation (students can't call mentors)

## 7. Call Flow Diagrams

### Mentor Initiating Call
```
1. Mentor taps call button
2. System creates call with student as member
3. Call sent with ringing: true
4. Mentor auto-joins call
5. Mentor sees "Waiting for participant..."
6. Student receives incoming call
7. Student accepts → both connected
   OR Student declines → mentor notified
```

### Incoming Call UI Summary (iOS)

| App State | UI Shown | Accept Action |
|-----------|----------|---------------|
| **Foreground** | Custom in-app UI (red/green buttons) | Joins call directly |
| **Background** | Native iOS CallKit UI | App opens → joins call (no in-app incoming UI) |
| **Terminated** | Native iOS CallKit UI | App launches → joins call (no in-app incoming UI) |

**Key Requirement:** Native CallKit should NEVER appear when app is in foreground.

### Student Receiving Call (App in Foreground)
```
1. Incoming call detected via SDK WebSocket listener
2. Custom in-app incoming call screen displayed (NOT CallKit)
3. Student taps Accept:
   a. Permissions requested (if not granted)
   b. If granted: join call, navigate to call screen
   c. If denied: show settings dialog
4. OR Student taps Decline:
   a. Call rejected via SDK
   b. Return to previous screen
```

### Student Receiving Call (App Backgrounded/Terminated)
```
iOS Flow:
1. Mentor initiates call → Stream sends VoIP push to APNs
2. APNs delivers VoIP push → iOS wakes app in background
3. PushKit callback received → CallKit reportNewIncomingCall()
4. Native iOS call UI appears (works on lock screen)
5. Student taps Accept:
   a. App launches to foreground
   b. StreamVideoService initializes (if needed)
   c. Join call, navigate to call screen
6. OR Student taps Decline:
   a. CallKit endCall() sent
   b. Stream notified, mentor sees declined
   c. App stays terminated/backgrounded

Android Flow:
1. Mentor initiates call → Stream sends FCM high-priority push
2. FCM delivers push → App's FirebaseMessagingService triggered
3. Foreground service started → Wake lock acquired
4. Full-screen notification/activity shown (works on lock screen)
5. Student taps Accept:
   a. App launches to foreground
   b. StreamVideoService initializes (if needed)
   c. Join call, navigate to call screen
6. OR Student taps Decline:
   a. Stream notified via API
   b. Mentor sees declined
   c. Service stopped, notification dismissed
```

## 8. Error Handling & Edge Cases

### EC-1: Network Loss During Call
- **Scenario:** Internet connection lost during active call
- **Behavior:** SDK handles reconnection automatically, show reconnecting indicator

### EC-2: Token Expiration
- **Scenario:** Stream Video token expires
- **Behavior:** Log expiration, don't initialize with expired token, user needs to re-authenticate

### EC-3: Permission Denied
- **Scenario:** User denies camera/microphone permissions
- **Behavior:** Show dialog explaining requirement, offer to open settings

### EC-4: Call Already Active
- **Scenario:** Mentor tries to call while already in a call
- **Behavior:** Clean up existing call before creating new one

### EC-5: Student Offline
- **Scenario:** Mentor calls student who is offline
- **Behavior:** Call created, mentor waits, student receives call when online (if within timeout)

### EC-6: App Backgrounded During Call
- **Scenario:** User switches to another app during call
- **Behavior:** Call continues (platform-dependent), wakelock released

### EC-7: Incoming Call While App Backgrounded
- **Scenario:** Student receives call while app is in background
- **Behavior:** VoIP push triggers native call UI (CallKit on iOS, full-screen notification on Android)

### EC-8: Incoming Call While App Terminated
- **Scenario:** Student receives call when app is completely closed
- **Behavior:**
  - iOS: VoIP push wakes app, CallKit shows native call UI
  - Android: FCM wakes device, foreground service shows full-screen call UI

### EC-9: VoIP Push Token Not Registered
- **Scenario:** Student's device token not registered with Stream
- **Behavior:** Fall back to regular push notification with "Missed Call" message, call times out

### EC-10: Multiple Devices
- **Scenario:** Student logged in on multiple devices
- **Behavior:** All devices ring, first to accept joins call, others stop ringing

### EC-11: Do Not Disturb Mode
- **Scenario:** Student's device in DND mode
- **Behavior:**
  - iOS: CallKit can bypass DND for calls (system setting)
  - Android: High-priority notification may still show (depends on DND settings)

## 9. Privacy & Security

### Data Protection
- Video streams encrypted in transit via Stream SDK
- No local recording of calls
- No call content stored on device
- Secure token authentication

### Access Control
- Only assigned mentor-student pairs can call
- Role validation before call initiation
- Channel isolation per call

## 10. Integration Points

### Authentication Service
- Stream Video token generation (`callGetStreamToken`)
- User authentication state
- User role (mentor/student)
- User profile data (name, avatar)

### Student Selection Service
- Selected student ID for call recipient
- Selected student name for display
- Mentor-student relationship validation

### Navigation (go_router)
- `/incoming-call/:callId` - Incoming call screen
- `/video-call/:callId` - Active call screen
- Query parameters for recipient/caller name

### Permissions Service
- Camera permission status
- Microphone permission status
- Settings redirect capability

### Push Notification Service
- VoIP push token registration (iOS)
- FCM token registration (Android)
- Push payload parsing for call metadata
- Background message handling

### Stream Dashboard Configuration
- VoIP push credentials uploaded
- Push notification templates configured
- Call ringing timeout configured

## 11. Dependencies

### Flutter Packages
- **Stream Video Flutter SDK:** `stream_video_flutter` - Core video calling
- **Permission Handler:** `permission_handler` - Runtime permissions
- **Wakelock:** `wakelock_plus` - Keep screen on during calls
- **State Management:** Provider for video service state
- **Navigation:** go_router for screen routing

### VoIP Push / CallKit Packages
- **flutter_callkit_incoming:** Native CallKit UI for iOS, full-screen call UI for Android
- OR **Stream SDK built-in CallKit support** (if available in `stream_video_flutter`)

### iOS Native Dependencies (via CocoaPods)
- PushKit framework (system)
- CallKit framework (system)

### Android Native Configuration
- Firebase Cloud Messaging (already configured)
- ConnectionService (optional, for system-level call management)

## 12. Future Enhancements

### Phase 2: Screen Sharing
- Screen share capability for mentors
- Document/presentation sharing during calls

### Phase 3: Group Calls
- Multiple students in a call
- Mentor hosting group sessions

### Phase 3: Call Recording
- Optional call recording with consent
- Recording storage and playback

## 13. Testing Requirements

### Unit Tests
- Token validation logic
- Call state management
- Permission status handling

### Integration Tests
- Full call flow with Stream Video backend
- Permission request flows
- Navigation between screens

### Manual Testing Checklist

#### Basic Call Flow
- [ ] Mentor can initiate call to selected student
- [ ] Student receives incoming call notification (app foreground)
- [ ] Accept call joins both participants
- [ ] Decline call properly notifies mentor
- [ ] Microphone toggle works
- [ ] Camera toggle works
- [ ] End call terminates for both parties
- [ ] Screen stays awake during call
- [ ] Proper cleanup after call ends
- [ ] Permission dialogs appear correctly
- [ ] Settings redirect works when permissions denied

#### Background/Terminated App Reception (iOS)
- [ ] VoIP push received when app backgrounded
- [ ] VoIP push received when app terminated
- [ ] CallKit UI appears on lock screen
- [ ] Accept from CallKit launches app and joins call
- [ ] Decline from CallKit notifies mentor without launching app
- [ ] Call appears in iOS Phone app recent calls

#### Background/Terminated App Reception (Android)
- [ ] FCM push received when app backgrounded
- [ ] FCM push received when app terminated
- [ ] Full-screen incoming call UI appears
- [ ] Incoming call UI appears on lock screen
- [ ] Accept launches app and joins call
- [ ] Decline notifies mentor without opening app
- [ ] Ringtone/vibration plays for incoming call

### Device Testing
- [ ] iOS physical device (simulator doesn't support VoIP push or camera)
- [ ] Android physical device
- [ ] Various network conditions (WiFi, cellular, poor connection)
- [ ] Device in Do Not Disturb mode
- [ ] Device with low battery / battery saver mode

## 14. Success Metrics

- Call connection success rate > 95%
- Average call setup time < 5 seconds
- Call quality satisfaction (future: in-app feedback)
- Feature adoption rate among mentors

---

**Priority:** Should Have (Post-MVP)
**Risk Level:** Medium (third-party service dependency, platform permissions complexity)
