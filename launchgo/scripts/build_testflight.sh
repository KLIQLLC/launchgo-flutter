#!/bin/bash

# Build script for Production TestFlight distribution
# Usage: bash scripts/build_stage_testflight.sh

echo "🚀 Building LaunchGo Production for TestFlight..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Increment build number automatically
echo -e "${YELLOW}🔢 Incrementing build number...${NC}"
current_version=$(grep "version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
version_name=$(echo $current_version | cut -d'+' -f1)
build_number=$(echo $current_version | cut -d'+' -f2)
new_build_number=$((build_number + 1))
new_version="${version_name}+${new_build_number}"
sed -i '' "s/version: .*/version: ${new_version}/" pubspec.yaml
echo -e "${GREEN}✅ Updated version to: ${new_version}${NC}"

# Clean and get dependencies
echo -e "${YELLOW}📦 Cleaning and updating dependencies...${NC}"
fvm flutter clean
fvm flutter pub get

# Build iOS with Flutter using stage flavor but production environment
echo -e "${YELLOW}🏗️ Building iOS for TestFlight (stage bundle ID + prod env)...${NC}"
fvm flutter build ios --flavor stage --dart-define=ENV=prod

# iOS specific setup
echo -e "${YELLOW}🍎 Setting up iOS dependencies...${NC}"
cd ios
pod install

# Build archive with Release-stage configuration
echo -e "${YELLOW}🏗️ Building iOS archive for TestFlight...${NC}"
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release-stage \
  -archivePath build/Runner-stage.xcarchive \
  -destination 'generic/platform=iOS' \
  clean archive

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Archive built successfully!${NC}"
    
    # Export IPA
    echo -e "${YELLOW}📦 Exporting IPA...${NC}"
    xcodebuild -exportArchive \
      -archivePath build/Runner-stage.xcarchive \
      -exportPath build/testflight-ipa \
      -exportOptionsPlist ExportOptions-stage.plist
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ IPA exported successfully!${NC}"
        echo -e "${GREEN}📍 IPA location: ios/build/testflight-ipa/${NC}"
        ls -la build/testflight-ipa/*.ipa
        
        echo -e "\n${YELLOW}📤 Next steps:${NC}"
        echo "1. Open Transporter app"
        echo "2. Sign in with your Apple ID"
        echo "3. Drag the IPA file from ios/build/testflight-ipa/"
        echo "4. Click Deliver"
        echo ""
        echo "Or use Xcode Organizer:"
        echo "1. Open Xcode → Window → Organizer"
        echo "2. Find the Runner-stage archive"
        echo "3. Click Distribute App"
    else
        echo -e "${RED}❌ IPA export failed!${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Archive build failed!${NC}"
    exit 1
fi

cd ..
echo -e "${GREEN}🎉 TestFlight build complete!${NC}"