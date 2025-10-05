#!/bin/bash

# Build and distribute Android app to Firebase App Distribution

# Check for environment parameter (stage or prod)
ENV_TYPE=${1:-prod}
RELEASE_NOTES=${2:-"Initial build"}

if [[ "$ENV_TYPE" != "stage" && "$ENV_TYPE" != "prod" ]]; then
    echo "Error: Invalid environment. Use 'stage' or 'prod'"
    echo "Usage: ./scripts/distribute_android.sh [stage|prod] [release_notes]"
    exit 1
fi

echo "Building Android app for $ENV_TYPE environment..."

# Build with appropriate flavor and environment
fvm flutter build apk --flavor $ENV_TYPE --dart-define=ENV=$ENV_TYPE

echo "Distributing to Firebase App Distribution..."

# Set Firebase app ID based on environment
if [[ "$ENV_TYPE" == "stage" ]]; then
    APP_ID="1:481027521494:android:21d8229e2c967842240277"
else
    APP_ID="1:481027521494:android:212d21e1bc94b4cd240277"
fi

# Distribute build
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-${ENV_TYPE}-release.apk \
  --app "$APP_ID" \
  --groups "testers" \
  --release-notes "$RELEASE_NOTES"

echo "Distribution complete for $ENV_TYPE!"