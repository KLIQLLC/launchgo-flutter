# launchgo Flutter Project

## Project Overview
launchgo is a Flutter application that provides user authentication, document management, and educational features. The app includes Firebase integration for backend services and authentication.

## Supported Platforms
This Flutter project supports **iOS and Android platforms only**. 
- Web, macOS, Windows, and Linux platforms are not supported
- Platform-specific code and configurations should only target iOS and Android

## Development Setup

### Prerequisites
- FVM (Flutter Version Management) - **REQUIRED**
- Flutter 3.35.4 (managed via FVM)
- Dart 3.9.2
- iOS development: Xcode and CocoaPods
- Android development: Android Studio

### Getting Started
```bash
# IMPORTANT: Always use FVM for Flutter commands
# Get dependencies
fvm flutter pub get

# iOS specific
cd ios && pod install && cd ..

# Run the app
fvm flutter run

# Run with environment variables
fvm flutter run --dart-define=ENV=stage  # Stage environment
fvm flutter run --dart-define=ENV=prod   # Production environment
```

## Common Commands

### Development
```bash
# IMPORTANT: All Flutter commands must use FVM
# Run the app
fvm flutter run

# Run on specific device
fvm flutter run -d <device_id>

# List available devices
fvm flutter devices

# Run with specific environment
fvm flutter run --dart-define=ENV=stage   # Stage environment
fvm flutter run --dart-define=ENV=prod    # Production environment
```

### Testing
```bash
# Run all tests
fvm flutter test

# Run tests with coverage
fvm flutter test --coverage
```

### Build
```bash
# Build for iOS
fvm flutter build ios

# Build for Android
fvm flutter build apk
fvm flutter build appbundle

# Build for TestFlight (may need updating for FVM)
./scripts/build_testflight.sh

# Distribute Android to Firebase App Distribution
./scripts/distribute_android.sh stage "Release notes"  # Stage environment
./scripts/distribute_android.sh prod "Release notes"   # Production environment
# Builds APK with appropriate flavor (stage/prod)
# Uses environment-specific Firebase app ID
# Distributes to Firebase App Distribution
# Targets 'testers' group automatically

# Clear tokens for testing
./scripts/clear_tokens.sh
```

### Code Quality
```bash
# Analyze code
fvm flutter analyze

# Format code
fvm dart format .
```

### Code Generation
```bash
# Generate code for Retrofit, JSON serialization, etc.
fvm flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode for auto-generation
fvm flutter pub run build_runner watch --delete-conflicting-outputs
```

### Dependencies
```bash
# Get packages
fvm flutter pub get

# Upgrade packages
fvm flutter pub upgrade

# Update dependencies
fvm flutter pub outdated
```

## Project Structure
- `lib/` - Main application code
  - `screens/` - Application screens (Login, Schedule, Courses, Chat, Recaps)
    - `schedule_screen.dart` - **Recently refactored** with improved widget organization
  - `features/` - Feature modules (Documents with BLoC pattern)
    - `documents/` - Document management feature
      - `presentation/` - UI layer (pages, widgets, BLoC)
      - `domain/` - Business logic (entities, repositories, use cases)
      - `data/` - Data layer (models, API implementation)
  - `widgets/` - Reusable UI components
  - `services/` - Business logic and API services
    - `auth_service.dart` - Authentication with Google Sign-In and user management
    - `api_service.dart` - HTTP API communication with role-based endpoints
    - `permissions_service.dart` - Centralized role-based permissions and UI logic
    - `preferences_service.dart` - User preferences storage (UserDefaults/SharedPreferences)
    - `theme_service.dart` - Theme management
    - `secure_storage_service.dart` - Secure token storage
  - `router/` - Navigation configuration (AppRouter with go_router)
  - `config/` - Configuration (environment settings)
  - `utils/` - Utility functions and helpers
- `test/` - Unit and widget tests
- `ios/` - iOS specific code and configuration
  - `Runner/GoogleService-Info.plist` - Firebase iOS configuration
- `android/` - Android specific code and configuration
  - `app/google-services.json` - Firebase Android configuration
- `assets/` - Images, fonts, and other assets
  - `icons/` - SVG icons for UI elements
- `scripts/` - Build and deployment scripts
- `pubspec.yaml` - Project configuration and dependencies

## Current Features

### Authentication
- **Google Sign-In**: OAuth authentication with Google
- **JWT Token Management**: Secure storage and validation
- **Silent Sign-In**: Automatic session restoration
- **Multi-role Support**: Student and Mentor user roles
- **Environment-specific Tokens**: Separate token storage per environment

### Chat & Presence Management
**Stream Chat Presence Behavior:**

**App Startup:**
1. **Students**: Connect to Stream Chat immediately when authenticated ✅
2. **Mentors**: Connect when a student is selected OR when restoring previously selected student ✅
3. **Selective Presence**: Mentors only appear online to their selected student ✅
4. **No false online status** - Prevents appearing online to all students ✅

**Student Selection & Presence:**
1. **Explicit Selection**: When mentor selects student from dropdown, immediate presence switch ✅
2. **Restored Selection**: When app restarts, mentor appears online to previously selected student ✅
3. **Persistent Storage**: Student selections saved and properly restored across app restarts ✅
4. **No Default Selection**: Dropdown doesn't auto-select first student unless previously chosen ✅

**When Mentor Switches Students:**
1. **Stop watching previous channel** - Previous student sees mentor offline ✅
2. **Watch new student's channel** - New student sees mentor online ✅
3. **Immediate presence update** - No delay in online/offline status changes ✅
4. **Unread message count updates** - Badge shows count for newly selected student ✅

**Technical Implementation:**
- **AuthService.selectStudent()**: Handles immediate presence switching when mentor changes students
- **Restored selections**: Non-blocking async connection for previously selected students on app startup
- **Selective channel watching**: Only watches channels for selected student, not all students
- **Connection management**: Students auto-connect, mentors connect selectively based on student selection

**Benefits:**
- Mentors only appear online to currently selected student
- Immediate presence updates when switching students
- Proper restoration of mentor presence on app restart
- No confusion about mentor availability across multiple students

### Document Management
- **Document List**: Browse documents with search and filter
- **Role-Based CRUD Operations**: 
  - Students: Read-only access (view and open documents)
  - Mentors/Case Managers: Full CRUD (create, read, update, delete)
- **Conditional UI Elements**: Create button and edit/delete actions hidden for students
- **Swipe to Delete**: Touch gesture for document deletion (disabled for students)
- **Course Filtering**: Filter documents by course
- **Search**: Real-time search by name and category
- **Sorting**: Documents sorted by last opened date (most recent first)
- **Empty States**: Consistent UI for empty content

### Role-Based System
- **User Roles**: Support for student, mentor, and case manager roles
- **Centralized Permissions**: `PermissionsService` manages all role-based logic in one place
- **Dynamic Navigation**: Role-based bottom navigation tabs
  - Students: 4 tabs (Schedule, Courses, Documents, Chat) - Recaps hidden
  - Mentors/Case Managers: 5 tabs (Schedule, Courses, Documents, Recaps, Chat)
- **Student Selection**: Mentors can select students from dropdown in app drawer
- **Persistent Selections**: Selected student and semester saved using UserDefaults (iOS) / SharedPreferences (Android)
- **Smart Restoration**: Student selections properly restored without auto-selecting first student by default
- **API Context**: Document operations use selected student ID for mentors
- **Route Protection**: Prevents unauthorized access to role-restricted screens

### Navigation & UI
- **Dynamic Bottom Navigation**: Tab count varies by role (4-5 tabs)
- **Protected Routes**: Automatic authentication redirects and role-based access
- **Dark/Light Theme**: Full theme support
- **Consistent Empty States**: Uniform design across all screens
- **Version Display**: Shows app version with environment indicator

### API Integration
- **REST API**: HTTP client with authentication headers
- **Environment Configuration**: Stage and Production environments
- **User ID Extraction**: Dynamic user ID from JWT tokens
- **Error Handling**: Comprehensive error states

## Architecture Decisions

### Date/Time Handling
- **UTC for Server Communication**: Always use UTC timestamps for API requests/responses and data storage
- **Local Time for Display**: Convert UTC to user's local timezone only when presenting dates/times in the UI
- **Consistent Comparisons**: Use UTC for all date comparisons (e.g., checking if assignments are overdue)
- **Benefits**: Ensures timezone-independent data consistency, prevents timezone-related bugs, and maintains synchronization between server and clients across different timezones

### State Management
- **Provider**: For app-wide state (auth, theme)
- **BLoC Pattern**: For feature-specific state (documents)
- **GetIt** (optional): Service locator for dependency injection

### Navigation
- **go_router**: Declarative routing with deep linking
- Protected routes with authentication guards
- Nested navigation with ShellRoute for bottom nav persistence

### Authentication Flow
1. User initiates Google Sign-In
2. Google authentication returns user credentials
3. Server auth code sent to backend
4. Backend returns JWT token
5. Token stored securely in device keychain
6. Silent restoration on app restart

### Security
- **flutter_secure_storage**: Encrypted token storage
- **JWT Token Validation**: Expiry checking
- **Environment Isolation**: Separate tokens per environment
- **No Hardcoded Credentials**: Dynamic user ID extraction

## Environment Configuration

### Stage Environment
- Base URL: Configured in environment
- Bundle ID: com.launchgo.stage (iOS)
- Used for development and testing

### Production Environment
- Base URL: Configured in environment
- Bundle ID: com.launchgo.prod (iOS)
- Used for TestFlight and App Store releases

## Build & Deployment

### iOS TestFlight Build
```bash
./scripts/build_testflight.sh
# Uses stage bundle ID with production environment
# Automatically increments build number
# Archives and prepares for upload
```

### Export Compliance
- ITSAppUsesNonExemptEncryption: NO
- Auto-incremented build numbers

## Known Issues & Solutions

### Silent Sign-In
- Uses `attemptLightweightAuthentication()` for session restoration
- Properly captures returned user object
- Falls back to manual sign-in if restoration fails

### Document Refresh
- FAB moved to DocumentsPage for proper BLoC context
- Automatic refresh after CRUD operations
- Pull-to-refresh functionality

### User Roles
- Supports both student and mentor roles
- Extracts appropriate ID from JWT token (studentId or mentorId)

## Testing Checklist
- [ ] Google Sign-In flow
- [ ] Token persistence across app restarts
- [ ] Document CRUD operations
- [ ] Swipe-to-delete gestures
- [ ] Search and filter functionality
- [ ] Environment switching
- [ ] Silent sign-in restoration
- [ ] Error states and retry logic

## Recent Changes

### Schedule Screen Refactoring (2025-09-17)
The `schedule_screen.dart` has been completely refactored with:
- **Widget Extraction**: Split into 15+ smaller, focused widgets
- **Better Organization**: Each widget has single responsibility
- **Improved Error Handling**: Dedicated error state with retry functionality
- **Constants**: Extracted magic numbers into named constants
- **Factory Pattern**: Status badges using factory constructors
- **Cleaner State Management**: Separated loading, error, and data states

Key extracted widgets:
- `_StudentHeader` - Student information display
- `_WeekNavigator` - Week navigation controls  
- `_AssignmentCard` - Individual assignment cards
- `_StatusBadge` - Completed/Overdue status indicators
- `_ErrorState` - Error display with retry

## Important Notes
- **ALWAYS use FVM**: Run all Flutter commands with `fvm flutter` prefix
- **Flutter Version**: Project uses Flutter 3.35.4 via FVM
- Always run `fvm flutter pub get` after modifying pubspec.yaml
- For iOS, run `cd ios && pod install` after adding new dependencies
- Check `fvm flutter doctor` if you encounter build issues
- Firebase configuration files contain sensitive information - never commit to public repositories
- Test authentication flows thoroughly before deployment
- Routes are defined in `lib/router/app_router.dart` for centralized navigation management
- App name is displayed as "launchgo" (lowercase) throughout the UI
- Code generation files (`.g.dart`) should not be edited manually