# Google Authentication Setup Guide

## Overview
This guide explains how to properly configure Google Sign-In to get `serverAuthCode` for backend authentication with refresh tokens.

## What You Need

### 1. **serverAuthCode**
- One-time authorization code
- Exchange for refresh token on backend
- Only provided on first sign-in
- Valid for a short time (~10 minutes)

### 2. **ID Token**
- JWT containing user info
- Use for API authentication
- Expires after 1 hour
- Can be refreshed

## Setup Steps

### 1. Google Cloud Console Configuration

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select or create your project
3. Enable Google Sign-In API
4. Create OAuth 2.0 Client IDs:

#### Web Client (Required for serverAuthCode)
- Type: Web application
- Name: LaunchGo Web Client
- Authorized JavaScript origins: Add your backend URL
- Authorized redirect URIs: Add your backend callback URL
- **Copy the Client ID** (e.g., `123456789-abc.apps.googleusercontent.com`)

#### iOS Client
- Type: iOS
- Bundle ID: Your iOS bundle ID
- Download `GoogleService-Info.plist`

#### Android Client  
- Type: Android
- Package name: Your Android package name
- SHA-1 certificate fingerprint
- Download `google-services.json`

### 2. Update Flutter Code

```dart
// lib/services/auth_service.dart
static const String _serverClientId = '123456789-abc.apps.googleusercontent.com'; // Your Web Client ID
```

### 2.1 Update Info.plist

In your new GoogleService-Info.plist, you’ll see something like:

<key>CLIENT_ID</key>
<string>1234567890-abcxyz.apps.googleusercontent.com</string>
<key>REVERSED_CLIENT_ID</key>
<string>com.googleusercontent.apps.1234567890-abcxyz</string>


CLIENT_ID → Goes into GIDClientID in Info.plist.
REVERSED_CLIENT_ID → Goes into CFBundleURLTypes in Info.plist.

### 3. Backend Implementation

Your backend needs to exchange the serverAuthCode for tokens:

```javascript
// Node.js example
const {OAuth2Client} = require('google-auth-library');

async function exchangeServerAuthCode(serverAuthCode) {
  const client = new OAuth2Client(
    CLIENT_ID,
    CLIENT_SECRET,
    REDIRECT_URI
  );
  
  const {tokens} = await client.getToken(serverAuthCode);
  
  // tokens.refresh_token - Store this securely
  // tokens.access_token - Use for Google API calls
  // tokens.id_token - Verify user identity
  
  return tokens;
}
```

## Important Notes

### serverAuthCode Behavior
- ✅ Provided on first sign-in
- ❌ NOT provided on subsequent sign-ins
- ❌ NOT provided with `signInSilently()`
- ✅ Only valid once
- ✅ Expires quickly (~10 minutes)

### Best Practices
1. **Send serverAuthCode immediately** to your backend
2. **Store refresh token** securely on backend
3. **Use ID token** for API authentication
4. **Handle token expiration** gracefully

### Testing Tips
1. Sign out completely: `_googleSignIn.disconnect()`
2. Clear app data to test first sign-in
3. Use different test accounts

## Troubleshooting

### No serverAuthCode received?
- Check `serverClientId` is set correctly (Web Client ID)
- Ensure user is signing in for first time
- User must not be signed in silently

### Invalid serverAuthCode?
- Check it's being sent immediately
- Verify backend is using correct client credentials
- Ensure code hasn't been used already

### Token refresh issues?
- Store refresh token on first sign-in
- Use refresh token to get new access tokens
- ID tokens can be refreshed using `getValidIdToken()`

## Security Considerations

1. **Never expose** client secret in Flutter app
2. **Always validate** ID tokens on backend
3. **Use HTTPS** for all API calls
4. **Store refresh tokens** securely on backend only
5. **Implement token rotation** for security

## Example Flow

1. User clicks "Sign in with Google"
2. Flutter gets `serverAuthCode` and `idToken`
3. Send `serverAuthCode` to backend immediately
4. Backend exchanges for `refresh_token` and stores it
5. Backend returns session token to Flutter
6. Flutter uses session token for API calls
7. Backend uses refresh token to maintain access