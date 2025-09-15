#!/bin/bash

# Build and distribute Android app to Firebase App Distribution

echo "Building Android app..."

# Build prod flavor with prod environment for demo
flutter build apk --flavor prod --dart-define=ENV=prod

echo "Distributing to Firebase App Distribution..."

# Distribute prod build with prod env
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-prod-release.apk \
  --app 1:481027521494:android:212d21e1bc94b4cd240277 \
  --groups "testers" \
  --release-notes "${1:-Initial build}"

echo "Distribution complete!"