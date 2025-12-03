#!/bin/bash

# Build and distribute iOS app to Firebase App Distribution
# Usage: ./scripts/distribute_ios.sh [stage|prod] [release_notes]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for environment parameter (stage or prod)
ENV_TYPE=${1:-prod}
RELEASE_NOTES=${2:-"iOS build"}

if [[ "$ENV_TYPE" != "stage" && "$ENV_TYPE" != "prod" ]]; then
    echo -e "${RED}Error: Invalid environment. Use 'stage' or 'prod'${NC}"
    echo "Usage: ./scripts/distribute_ios.sh [stage|prod] [release_notes]"
    exit 1
fi

echo -e "${YELLOW}🍎 Building iOS app for $ENV_TYPE environment...${NC}"

# Set Firebase app ID based on environment
if [[ "$ENV_TYPE" == "stage" ]]; then
    APP_ID="1:481027521494:ios:9152d81d325b79f7240277"
    CONFIG="Release-stage"
    ARCHIVE_PATH="build/Runner-stage.xcarchive"
    IPA_PATH="build/firebase-ipa-stage"
else
    APP_ID="1:481027521494:ios:2760c2f2a2337b99240277"
    CONFIG="Release-prod"
    ARCHIVE_PATH="build/Runner-prod.xcarchive"
    IPA_PATH="build/firebase-ipa-prod"
fi

# Clean and get dependencies
echo -e "${YELLOW}📦 Cleaning and updating dependencies...${NC}"
fvm flutter clean
fvm flutter pub get

# Build iOS with Flutter
echo -e "${YELLOW}🏗️ Building iOS with flavor $ENV_TYPE...${NC}"
fvm flutter build ios --flavor $ENV_TYPE --dart-define=ENV=$ENV_TYPE --no-codesign

# iOS specific setup
echo -e "${YELLOW}🍎 Installing pods...${NC}"
cd ios
pod install

# Build archive
echo -e "${YELLOW}🏗️ Building iOS archive ($CONFIG)...${NC}"
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration $CONFIG \
  -archivePath $ARCHIVE_PATH \
  -destination 'generic/platform=iOS' \
  clean archive

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Archive build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Archive built successfully!${NC}"

# Export IPA using existing export options (uses automatic signing)
echo -e "${YELLOW}📦 Exporting IPA...${NC}"
xcodebuild -exportArchive \
  -archivePath $ARCHIVE_PATH \
  -exportPath $IPA_PATH \
  -exportOptionsPlist ExportOptions-${ENV_TYPE}.plist

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ IPA export failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ IPA exported successfully!${NC}"

# Find the IPA file
IPA_FILE=$(find $IPA_PATH -name "*.ipa" | head -1)

if [ -z "$IPA_FILE" ]; then
    echo -e "${RED}❌ IPA file not found in $IPA_PATH${NC}"
    exit 1
fi

echo -e "${YELLOW}📤 Distributing to Firebase App Distribution...${NC}"
echo "IPA: $IPA_FILE"
echo "App ID: $APP_ID"

cd ..

# Distribute to Firebase
firebase appdistribution:distribute "ios/$IPA_FILE" \
  --app "$APP_ID" \
  --groups "testers" \
  --release-notes "$RELEASE_NOTES"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}🎉 Distribution complete for $ENV_TYPE!${NC}"
else
    echo -e "${RED}❌ Firebase distribution failed!${NC}"
    exit 1
fi
