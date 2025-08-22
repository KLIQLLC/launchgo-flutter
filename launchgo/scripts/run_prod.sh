#!/bin/bash

echo "Running LaunchGo in PRODUCTION environment..."
flutter run --flavor prod --dart-define=ENV=prod "$@"