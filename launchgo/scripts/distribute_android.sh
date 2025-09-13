#!/bin/bash

# Build and distribute Android app to Firebase App Distribution

echo "Building Android app..."

# Build stage flavor with prod environment for demo
flutter build apk --flavor stage --dart-define=ENV=prod

echo "Distributing to Firebase App Distribution..."

# Distribute stage build with prod env
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-stage-release.apk \
  --app 1:481027521494:android:21d8229e2c967842240277 \
  --groups "testers" \
  --release-notes "${1:-Initial build}"

echo "Distribution complete!"