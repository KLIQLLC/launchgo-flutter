#!/bin/bash

echo "Running LaunchGo in STAGE environment..."
fvm flutter run --flavor stage --dart-define=ENV=stage "$@"