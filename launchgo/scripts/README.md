# LaunchGo Scripts

All scripts have been updated to use FVM (Flutter Version Management) to ensure consistent Flutter version (3.35.4) across all environments.

## Available Scripts

### Running the App

#### `run_stage.sh`
Runs the app in STAGE environment with stage endpoints.
```bash
./scripts/run_stage.sh
```

#### `run_prod.sh`
Runs the app in PRODUCTION environment with production endpoints.
```bash
./scripts/run_prod.sh
```

### Building for Release

#### `build_testflight.sh`
Builds iOS app for TestFlight distribution (stage bundle ID with prod environment).
- Auto-increments build number
- Cleans and rebuilds
- Creates .xcarchive and .ipa files
- Ready for upload via Transporter or Xcode Organizer
```bash
./scripts/build_testflight.sh
```

#### `distribute_android.sh`
Builds Android APK and distributes to Firebase App Distribution.
```bash
./scripts/distribute_android.sh "Release notes here"
```

### Utilities

#### `clear_tokens.sh`
Reference script for understanding token storage (tokens are securely stored in device keychain/keystore).
```bash
./scripts/clear_tokens.sh
```

## Important Notes

1. **All scripts use FVM** - Ensure FVM is installed before running any script
2. **Flutter version**: 3.35.4 (managed by FVM)
3. **Make scripts executable**: Run `chmod +x scripts/*.sh` if needed
4. **Environment variables**: Scripts use `--dart-define=ENV=` for environment configuration

## FVM Setup

If FVM is not installed:
```bash
# Install FVM
dart pub global activate fvm

# Install Flutter 3.35.4
fvm install 3.35.4

# Use it in project
fvm use 3.35.4
```

## Troubleshooting

- **Permission denied**: Make scripts executable with `chmod +x scripts/*.sh`
- **FVM not found**: Ensure FVM is in your PATH
- **Build failures**: Run `fvm flutter clean && fvm flutter pub get`
- **iOS build issues**: Check Xcode and certificates are properly configured
- **Android build issues**: Check Android Studio and SDK are properly configured