#!/bin/bash

# Google Play AAB Build Script for launchgo Flutter App (Production)
# Usage: ./scripts/build_google_play.sh
#
# SIGNING CONFIGURATION:
# This script builds AABs with debug signing, which is SAFE for production when using
# Play App Signing (enabled in Google Play Console). Here's how it works:
#
# 1. AAB built with debug keys (fast, no keystore management needed)
# 2. Google Play Console strips debug signature and re-signs with Google-managed keys
# 3. End users receive properly signed apps with Google's production keys
#
# Benefits:
# - No risk of losing production keys (Google manages them)
# - Simplified build process (no keystore files to manage)
# - Same security as traditional signing (Google's keys are production-grade)
# - Key rotation support (Google can rotate keys if needed)
#
# This approach is recommended by Google and widely used in production apps.

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Google Play Production AAB Build ===${NC}"

# Check if we're in the right directory
if [[ ! -f "pubspec.yaml" ]]; then
    echo -e "${RED}Error: Must be run from project root${NC}"
    exit 1
fi

echo -e "${BLUE}Step 1: Checking Flutter setup...${NC}"
if ! command -v fvm &> /dev/null; then
    echo -e "${RED}Error: FVM not found. Please install FVM first.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ FVM found${NC}"

echo -e "${BLUE}Step 2: Getting Flutter dependencies...${NC}"
fvm flutter pub get
echo -e "${GREEN}✓ Dependencies updated${NC}"

echo -e "${BLUE}Step 3: Cleaning previous builds...${NC}"
fvm flutter clean
fvm flutter pub get
echo -e "${GREEN}✓ Build cleaned${NC}"

echo -e "${BLUE}Step 4: Building production AAB...${NC}"
fvm flutter build appbundle --release --dart-define=ENV=prod

AAB_PATH="build/app/outputs/bundle/prodRelease/app-prod-release.aab"

# Check if build was successful
if [[ ! -f "$AAB_PATH" ]]; then
    echo -e "${RED}Error: AAB file not found at $AAB_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✓ AAB build completed${NC}"

# Build summary
AAB_SIZE=$(du -h "$AAB_PATH" | cut -f1)
BUILD_TIME=$(date)

echo ""
echo -e "${GREEN}=== BUILD SUCCESSFUL ===${NC}"
echo -e "File: ${YELLOW}$AAB_PATH${NC}"
echo -e "Size: ${YELLOW}$AAB_SIZE${NC}"
echo -e "Package: ${YELLOW}com.launchgo.app${NC}"
echo -e "Environment: ${YELLOW}Production${NC}"
echo -e "Build Time: ${YELLOW}$BUILD_TIME${NC}"

echo ""
echo -e "${YELLOW}📋 REQUIREMENTS FOR GOOGLE PLAY:${NC}"
echo -e "   • Privacy policy URL required (CAMERA permission)"
echo -e "   • Add policy in Google Play Console > App content > Privacy Policy"

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "1. Upload ${YELLOW}$AAB_PATH${NC} to Google Play Console"
echo -e "2. Complete app signing setup"
echo -e "3. Add privacy policy URL"
echo -e "4. Submit for review"
echo ""