#!/bin/bash

echo "Running LaunchGo in PRODUCTION environment..."
fvm flutter run --flavor prod --dart-define=ENV=prod "$@"