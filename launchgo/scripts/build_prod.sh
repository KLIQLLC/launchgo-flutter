#!/bin/bash

echo "Building LaunchGo for PRODUCTION environment..."

if [ "$1" == "ios" ]; then
    echo "Building iOS app for PRODUCTION..."
    flutter build ios --flavor prod --dart-define=ENV=prod "${@:2}"
elif [ "$1" == "android" ]; then
    echo "Building Android app for PRODUCTION..."
    flutter build apk --flavor prod --dart-define=ENV=prod "${@:2}"
elif [ "$1" == "appbundle" ]; then
    echo "Building Android App Bundle for PRODUCTION..."
    flutter build appbundle --flavor prod --dart-define=ENV=prod "${@:2}"
else
    echo "Please specify platform: ios, android, or appbundle"
    echo "Example: ./scripts/build_prod.sh ios"
    echo "Example: ./scripts/build_prod.sh android"
    echo "Example: ./scripts/build_prod.sh appbundle"
    exit 1
fi