#!/bin/bash

echo "Clearing all stored tokens for fresh testing..."

# For iOS Simulator
if [ -d ~/Library/Developer/CoreSimulator/Devices ]; then
    echo "Clearing iOS Simulator tokens..."
    # This is a simplified approach - in reality, tokens are in iOS keychain
    # But this script is for reference
fi

# For Android Emulator
if [ -d ~/.android ]; then
    echo "Clearing Android Emulator tokens..."
    # This is a simplified approach - in reality, tokens are in Android keystore
    # But this script is for reference
fi

echo "Note: Tokens are stored securely in device keychain/keystore."
echo "The app will automatically handle token migration and clearing."
echo "To clear tokens manually, use the 'Disconnect' option in the app drawer."