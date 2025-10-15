#!/bin/bash

echo "🔍 Checking Push Notification Setup..."
echo

# Check if entitlements file exists
if [ -f "ios/Runner/Runner.entitlements" ]; then
    echo "✅ Entitlements file exists"
    echo "📄 Contents:"
    cat ios/Runner/Runner.entitlements
else
    echo "❌ Entitlements file missing"
fi

echo
echo "🔍 Checking Firebase configuration..."

# Check Firebase config files
if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo "✅ Firebase iOS config exists"
else
    echo "❌ Firebase iOS config missing"
fi

if [ -f "android/app/google-services.json" ]; then
    echo "✅ Firebase Android config exists"
else
    echo "❌ Firebase Android config missing"
fi

echo
echo "🔍 Checking Firebase Messaging dependency..."
if grep -q "firebase_messaging" pubspec.yaml; then
    echo "✅ Firebase Messaging dependency found"
    grep "firebase_messaging" pubspec.yaml
else
    echo "❌ Firebase Messaging dependency missing"
fi

echo
echo "📱 Next steps:"
echo "1. Open ios/Runner.xcworkspace in Xcode"
echo "2. Select Runner target → Signing & Capabilities"
echo "3. Add 'Push Notifications' capability"
echo "4. Add 'Background Modes' capability"
echo "5. Enable 'Remote notifications' background mode"
echo "6. Build and test on device"