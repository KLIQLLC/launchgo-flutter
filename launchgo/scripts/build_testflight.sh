#!/bin/bash

# Build script for Production TestFlight distribution
# Usage: bash scripts/build_stage_testflight.sh

# If someone runs `sh scripts/build_testflight.sh`, re-exec under bash.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

echo "🚀 Building LaunchGo Production for TestFlight..."
# Always operate relative to repo root (prevents reading a different pubspec.yaml
# if the script is launched from another working directory).
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PUBSPEC_FILE="$ROOT_DIR/pubspec.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Increment build number automatically
printf "%b\n" "${YELLOW}🔢 Incrementing build number...${NC}"
printf "%b\n" "${YELLOW}📄 Using pubspec: ${PUBSPEC_FILE}${NC}"
current_version=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //' | tr -d ' ')
printf "%b\n" "${YELLOW}📌 Current version: ${current_version}${NC}"
version_name=$(echo $current_version | cut -d'+' -f1)
build_number=$(echo $current_version | cut -d'+' -f2)
new_build_number=$((build_number + 1))
new_version="${version_name}+${new_build_number}"
if [ "${SKIP_VERSION_BUMP:-0}" = "1" ]; then
  printf "%b\n" "${YELLOW}⚠️ SKIP_VERSION_BUMP=1 (not modifying pubspec)${NC}"
else
  sed -i '' "s/^version: .*/version: ${new_version}/" "$PUBSPEC_FILE"
  printf "%b\n" "${GREEN}✅ Updated version to: ${new_version}${NC}"
fi

# Clean and get dependencies
printf "%b\n" "${YELLOW}📦 Cleaning and updating dependencies...${NC}"
cd "$ROOT_DIR"
fvm flutter clean
fvm flutter pub get

# Build iOS with Flutter using production configuration
printf "%b\n" "${YELLOW}🏗️ Building iOS for TestFlight (production bundle ID + prod env)...${NC}"
fvm flutter build ios --flavor prod --dart-define=ENV=prod

# iOS specific setup
printf "%b\n" "${YELLOW}🍎 Setting up iOS dependencies...${NC}"
cd ios
pod install

# Build archive with Release-prod configuration
printf "%b\n" "${YELLOW}🏗️ Building iOS archive for TestFlight...${NC}"
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release-prod \
  -archivePath build/Runner-prod.xcarchive \
  -destination 'generic/platform=iOS' \
  clean archive

if [ $? -eq 0 ]; then
    printf "%b\n" "${GREEN}✅ Archive built successfully!${NC}"
    
    # Export IPA
    printf "%b\n" "${YELLOW}📦 Exporting IPA...${NC}"
    xcodebuild -exportArchive \
      -archivePath build/Runner-prod.xcarchive \
      -exportPath build/testflight-ipa \
      -exportOptionsPlist ExportOptions-prod.plist
    
    if [ $? -eq 0 ]; then
        printf "%b\n" "${GREEN}✅ IPA exported successfully!${NC}"
        printf "%b\n" "${GREEN}📍 IPA location: ios/build/testflight-ipa/${NC}"
        ls -la build/testflight-ipa/*.ipa
        
        printf "\n%b\n" "${YELLOW}📤 Next steps:${NC}"
        echo "1. Open Transporter app"
        echo "2. Sign in with your Apple ID"
        echo "3. Drag the IPA file from ios/build/testflight-ipa/"
        echo "4. Click Deliver"
        echo ""
        echo "Or use Xcode Organizer:"
        echo "1. Open Xcode → Window → Organizer"
        echo "2. Find the Runner-prod archive"
        echo "3. Click Distribute App"
    else
        printf "%b\n" "${RED}❌ IPA export failed!${NC}"
        exit 1
    fi
else
    printf "%b\n" "${RED}❌ Archive build failed!${NC}"
    exit 1
fi

cd ..
printf "%b\n" "${GREEN}🎉 TestFlight build complete!${NC}"