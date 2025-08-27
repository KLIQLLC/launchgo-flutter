# launchgo Flutter Project

## Project Overview
launchgo is a Flutter application that provides user authentication, document management, and educational features. The app includes Firebase integration for backend services and authentication.

## Supported Platforms
This Flutter project supports **iOS and Android platforms only**. 
- Web, macOS, Windows, and Linux platforms are not supported
- Platform-specific code and configurations should only target iOS and Android

## Development Setup

### Prerequisites
- Flutter SDK (^3.8.1)
- Dart SDK
- iOS development: Xcode and CocoaPods
- Android development: Android Studio

### Getting Started
```bash
# Get dependencies
flutter pub get

# iOS specific
cd ios && pod install && cd ..

# Run the app
flutter run

# Run with environment variables
flutter run --dart-define=ENV=stage  # Stage environment
flutter run --dart-define=ENV=prod   # Production environment
```

## Common Commands

### Development
```bash
# Run the app
flutter run

# Run on specific device
flutter run -d <device_id>

# List available devices
flutter devices

# Run with specific environment
./scripts/run_stage.sh   # Run in stage environment
./scripts/run_prod.sh    # Run in production environment
```

### Testing
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage
```

### Build
```bash
# Build for iOS
flutter build ios

# Build for Android
flutter build apk
flutter build appbundle

# Build for TestFlight
./scripts/build_testflight.sh

# Clear tokens for testing
./scripts/clear_tokens.sh
```

### Code Quality
```bash
# Analyze code
flutter analyze

# Format code
dart format .
```

### Dependencies
```bash
# Get packages
flutter pub get

# Upgrade packages
flutter pub upgrade

# Update dependencies
flutter pub outdated
```

## Project Structure
- `lib/` - Main application code
  - `screens/` - Application screens (Login, Schedule, Courses, Chat, Recaps)
  - `features/` - Feature modules (Documents with BLoC pattern)
    - `documents/` - Document management feature
      - `presentation/` - UI layer (pages, widgets, BLoC)
      - `domain/` - Business logic (entities, repositories, use cases)
      - `data/` - Data layer (models, API implementation)
  - `widgets/` - Reusable UI components
  - `services/` - Business logic and API services
    - `auth_service.dart` - Authentication with Google Sign-In
    - `api_service.dart` - HTTP API communication
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

### Document Management
- **Document List**: Browse documents with search and filter
- **CRUD Operations**: Create, read, update, delete documents
- **Swipe to Delete**: Touch gesture for document deletion (40% swipe limit)
- **Course Filtering**: Filter documents by course
- **Search**: Real-time search by name and category
- **Sorting**: Documents sorted by creation date (newest first)
- **Empty States**: Consistent UI for empty content

### Navigation & UI
- **Bottom Navigation**: 5 main tabs (Schedule, Courses, Documents, Recaps, Chat)
- **Protected Routes**: Automatic authentication redirects
- **Dark/Light Theme**: Full theme support
- **Consistent Empty States**: Uniform design across all screens
- **Version Display**: Shows app version with environment indicator

### API Integration
- **REST API**: HTTP client with authentication headers
- **Environment Configuration**: Stage and Production environments
- **User ID Extraction**: Dynamic user ID from JWT tokens
- **Error Handling**: Comprehensive error states

## Architecture Decisions

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

## Important Notes
- Always run `flutter pub get` after modifying pubspec.yaml
- For iOS, run `cd ios && pod install` after adding new dependencies
- Check `flutter doctor` if you encounter build issues
- Firebase configuration files contain sensitive information - never commit to public repositories
- Test authentication flows thoroughly before deployment
- Routes are defined in `lib/router/app_router.dart` for centralized navigation management
- App name is displayed as "launchgo" (lowercase) throughout the UI