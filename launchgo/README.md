# LaunchGo Flutter Project

## Project Overview
This is a Flutter application for LaunchGo.

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
flutter run --release -d 00008120-001A75002628C01E

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
- `test/` - Unit and widget tests
- `ios/` - iOS specific code and configuration
- `android/` - Android specific code and configuration
- `assets/` - Images, fonts, and other assets
- `pubspec.yaml` - Project configuration and dependencies

## Important Notes
- Always run `flutter pub get` after modifying pubspec.yaml
- For iOS, run `cd ios && pod install` after adding new dependencies
- Check `flutter doctor` if you encounter build issues