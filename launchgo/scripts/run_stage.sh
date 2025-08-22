#!/bin/bash

echo "Running LaunchGo in STAGE environment..."
flutter run --flavor stage --dart-define=ENV=stage "$@"