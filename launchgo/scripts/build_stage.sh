#!/bin/bash

echo "Building LaunchGo for STAGE environment..."

if [ "$1" == "ios" ]; then
    echo "Building iOS app for STAGE..."
    flutter build ios --flavor stage --dart-define=ENV=stage "${@:2}"
elif [ "$1" == "android" ]; then
    echo "Building Android app for STAGE..."
    flutter build apk --flavor stage --dart-define=ENV=stage "${@:2}"
elif [ "$1" == "appbundle" ]; then
    echo "Building Android App Bundle for STAGE..."
    flutter build appbundle --flavor stage --dart-define=ENV=stage "${@:2}"
else
    echo "Please specify platform: ios, android, or appbundle"
    echo "Example: ./scripts/build_stage.sh ios"
    echo "Example: ./scripts/build_stage.sh android"
    echo "Example: ./scripts/build_stage.sh appbundle"
    exit 1
fi