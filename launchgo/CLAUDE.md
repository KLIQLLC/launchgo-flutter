# LaunchGo Flutter Project

## Project Overview
LaunchGo is a Flutter application that provides user authentication and management features. The app includes Firebase integration for backend services and authentication.

## Supported Platforms
This Flutter project supports **iOS and Android platforms only**. 
- Web, macOS, Windows, and Linux platforms are not supported
- Platform-specific code and configurations should only target iOS and Android

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
- URL-based routing for deep linking support on iOS and Android

### State Management & Dependency Injection
- **Provider** for reactive state management and UI updates
- **GetIt** (optional) for service locator pattern and dependency injection
- AuthService as a ChangeNotifier for reactive authentication state
- Centralized authentication logic separated from UI

#### DI Options:
1. **Current: Provider Only** (`main.dart`)
   - Simple, Flutter-native solution
   - Good for small to medium apps
   - Services registered in main.dart
   
2. **Available: GetIt + Provider Hybrid** (`main_with_getit.dart`)
   - GetIt for service location and non-UI dependencies
   - Provider for reactive UI state
   - Better testability and modularity
   - See `lib/core/di/service_locator.dart` for service registration
   - To use: rename `main_with_getit.dart` to `main.dart`
   
#### Using GetIt in the app:
```dart
// Get service instance anywhere
final authService = getIt<AuthService>();
final apiService = getIt<ApiService>();

// In widgets (if not using Provider)
import 'package:launchgo/core/di/service_locator.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = getIt<AuthService>();
    // Use authService...
  }
}
```

### Authentication & Security
- **Google Sign-In** for user authentication
- **Retrofit + Dio** for API communication with backend
- **flutter_secure_storage** for encrypted storage of sensitive data (JWT tokens)
- **jwt_decoder** for parsing JWT tokens and extracting metadata
- Access tokens are securely stored and persist across app sessions
- Token expiry is tracked and validated

## Important Notes
- Always run `flutter pub get` after modifying pubspec.yaml
- For iOS, run `cd ios && pod install` after adding new dependencies
- Check `flutter doctor` if you encounter build issues
- Firebase configuration files contain sensitive information - never commit to public repositories
- Test authentication flows thoroughly before deployment
- Routes are defined in `lib/router/app_router.dart` for centralized navigation management