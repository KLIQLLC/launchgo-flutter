# LaunchGo Flutter Project

## Project Overview
LaunchGo is a Flutter application that provides user authentication and management features. The app includes Firebase integration for backend services and authentication.

## Development Setup

### Prerequisites
- Flutter SDK
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
  - `screens/` - Application screens (Login, Schedule, Courses, Documents, Recaps)
  - `widgets/` - Reusable UI components
  - `services/` - Business logic and API services (AuthService)
  - `router/` - Navigation configuration (AppRouter with go_router)
  - `models/` - Data models
  - `utils/` - Utility functions and helpers
- `test/` - Unit and widget tests
- `ios/` - iOS specific code and configuration
  - `Runner/GoogleService-Info.plist` - Firebase iOS configuration
- `android/` - Android specific code and configuration
  - `app/google-services.json` - Firebase Android configuration (to be added)
- `assets/` - Images, fonts, and other assets
- `pubspec.yaml` - Project configuration and dependencies

## Firebase Setup

### iOS Configuration
- Firebase configuration file is located at `ios/Runner/GoogleService-Info.plist`
- CocoaPods dependencies are already configured for Firebase

### Android Configuration
- Add `google-services.json` to `android/app/` directory
- Configure Firebase in Android gradle files when needed

## Current Features
- **Login Screen**: Google Sign-In authentication
- **Firebase Integration**: Backend services ready for authentication and data storage
- **Navigation**: go_router implementation with protected routes and deep linking support
- **Bottom Navigation**: 4 main tabs (Schedule, Courses, Documents, Recaps)
- **Authentication Service**: Centralized auth state management with Provider

## Architecture Decisions

### Navigation
- **go_router** for declarative routing with deep linking support
- Protected routes with automatic authentication redirects
- Nested navigation using ShellRoute for persistent bottom navigation
- URL-based routing for web compatibility

### State Management
- **Provider** for dependency injection and state management
- AuthService as a ChangeNotifier for reactive authentication state
- Centralized authentication logic separated from UI

## Important Notes
- Always run `flutter pub get` after modifying pubspec.yaml
- For iOS, run `cd ios && pod install` after adding new dependencies
- Check `flutter doctor` if you encounter build issues
- Firebase configuration files contain sensitive information - never commit to public repositories
- Test authentication flows thoroughly before deployment
- Routes are defined in `lib/router/app_router.dart` for centralized navigation management