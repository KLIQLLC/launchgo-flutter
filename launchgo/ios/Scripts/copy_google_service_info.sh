#!/bin/bash

# This script copies the appropriate GoogleService-Info.plist based on the bundle identifier

BUNDLE_ID="${PRODUCT_BUNDLE_IDENTIFIER}"
echo "Bundle ID: ${BUNDLE_ID}"

# Path to the plist files
STAGE_PLIST="${PROJECT_DIR}/Runner/GoogleService-Info-stage.plist"
PROD_PLIST="${PROJECT_DIR}/Runner/GoogleService-Info-prod.plist"
TARGET_PLIST="${PROJECT_DIR}/Runner/GoogleService-Info.plist"

if [[ "${BUNDLE_ID}" == *".stage"* ]]; then
    echo "Using Stage GoogleService-Info.plist"
    if [ -f "$STAGE_PLIST" ]; then
        cp "$STAGE_PLIST" "$TARGET_PLIST"
    else
        echo "Warning: ${STAGE_PLIST} not found"
    fi
elif [[ "${BUNDLE_ID}" == *".app"* ]]; then
    echo "Using Production GoogleService-Info.plist"
    if [ -f "$PROD_PLIST" ]; then
        cp "$PROD_PLIST" "$TARGET_PLIST"
    else
        echo "Warning: ${PROD_PLIST} not found"
    fi
else
    echo "Warning: Unknown bundle ID pattern: ${BUNDLE_ID}"
fi