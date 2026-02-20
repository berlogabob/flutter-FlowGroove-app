# Troubleshooting Guide

## Spotify API Configuration

### Current Status: ✅ Pre-configured for Development

The Spotify API credentials are **pre-configured** for development and testing. You should be able to use the Spotify integration out of the box.

**Credentials configured:**
- Client ID: `92576bcea9074252ad0f02f95d093a3b`
- Client Secret: `5a09b161559b4a3386dd340ec1519e6c`
- App Name: RepSync
- Redirect URI: `https://berlogabob.github.io/flutter-repsync-app`

### For Production Deployment

⚠️ **Important:** For production deployments, you should obtain your own Spotify API credentials:

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Create your own app
3. Replace the credentials in:
   - `.env` file (for local development)
   - `web/config.js` (for web deployment)

### How to Verify Credentials Are Working

1. Run the app: `flutter run -d chrome`
2. Go to Songs → Add Song (+)
3. Click **"Search Spotify"** button
4. Enter a song title (e.g., "Shape of You Ed Sheeran")
5. You should see search results with BPM and Key displayed
6. Select a track → BPM and Key fields should populate automatically

If you see results with BPM and Key, the credentials are working correctly.

---

## Issue 1: BPM Fetching Not Working

### Problem
When you click "Fetch BPM" or select a track from Spotify, the BPM and key fields remain empty.

### Root Cause
The Spotify API requires **valid API credentials** (Client ID and Client Secret). The current code has placeholder values.

### Solution

#### Step 1: Get Spotify API Credentials

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Log in with your Spotify account (must have Spotify Premium)
3. Click **"Create app"**
4. Fill in:
   - **App name**: RepSync (or any name)
   - **App description**: Band repertoire management
   - **Redirect URI**: `http://localhost:8080/callback` (not used, but required)
   - Check the box for "Web Playback API"
5. Click **Save**
6. Click on your app → **Settings**
7. Copy **Client ID** and **Client Secret**

#### Step 2: Add Credentials to Your App

**Option A: For Web Development (Recommended)**

Edit `web/config.js`:
```javascript
window.env = {
  "SPOTIFY_CLIENT_ID": "YOUR_ACTUAL_CLIENT_ID_HERE",
  "SPOTIFY_CLIENT_SECRET": "YOUR_ACTUAL_CLIENT_SECRET_HERE"
};
```

**Option B: For Mobile/Desktop Development**

Create `.env` file in project root:
```
SPOTIFY_CLIENT_ID=YOUR_ACTUAL_CLIENT_ID_HERE
SPOTIFY_CLIENT_SECRET=YOUR_ACTUAL_CLIENT_SECRET_HERE
```

#### Step 3: Restart the App

```bash
# Stop the app if running
# Then restart
flutter run -d chrome
```

#### Step 4: Test BPM Fetching

1. Go to Songs → Add Song (+)
2. Click **"Search Spotify"** button
3. Enter a song title (e.g., "Shape of You Ed Sheeran")
4. You should see search results with BPM and Key
5. Select a track → BPM and Key fields should populate

---

### Alternative: Use MusicBrainz (Free, No API Key)

If you don't have Spotify Premium, you can use MusicBrainz:

1. Go to Songs → Add Song (+)
2. Click **"Search MusicBrainz"** button
3. Enter a song title
4. Select a track (note: MusicBrainz doesn't provide BPM, only title/artist)
5. Manually enter BPM

---

### Alternative: Use Track Analysis API

The app also supports RapidAPI's Track Analysis:

1. Go to [RapidAPI Track Analysis](https://rapidapi.com/rapidapi-1-default/api/track-analysis)
2. Subscribe to the API (free tier available)
3. Get your API key
4. The app will automatically use it when available

---

## Issue 2: Join Band - "Invalid Code"

### Problem
When trying to join a band with an invite code, you get "Invalid code" error.

### Root Cause
The current implementation only searches for bands in the **current user's Firestore collection**. This means:
- User A creates a band → stored in `/users/UserA/bands/`
- User B tries to join → searches in `/users/UserB/bands/` (doesn't exist yet)
- Result: "Invalid code" because the band isn't in User B's collection

### Current Workaround

**Method 1: Share Band Data Manually (Temporary Fix)**

1. Band creator exports band data
2. New member imports it
3. Not ideal, but works for testing

**Method 2: Use Same User Account (For Testing)**

1. Log in with the same account on multiple devices
2. Create band on device 1
3. Join band on device 2 (will work because it's the same user)
4. Not suitable for production

### Proper Solution (Requires Code Changes)

The band data should be stored in a **global collection** accessible to all users:

#### Current Structure (Broken)
```
/users/{userId}/bands/{bandId}  // Only visible to user
```

#### Proposed Structure (Fixed)
```
/bands/{bandId}              // Global band collection
  - id, name, members[], inviteCode
/bands/{bandId}/members/{userId}  // Subcollection for members
```

### Implementation Steps

This requires changes to:
1. `lib/services/firestore_service.dart` - Add global bands collection
2. `lib/screens/bands/join_band_screen.dart` - Query global collection
3. `lib/screens/bands/create_band_screen.dart` - Save to global collection
4. Firestore Security Rules - Update for global access

**Estimated Time:** 2-3 hours

---

## Quick Fix for Testing Join Band

If you want to test the join band functionality **right now** without code changes:

### Method: Direct Firestore Access

1. **Create Band** (User A):
   - Log in as User A
   - Create a band
   - Note the invite code (e.g., `ABC123`)

2. **Manually Add Member** (in Firebase Console):
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project → Firestore Database
   - Navigate to: `users → UserA → bands → {bandId}`
   - Click on the band document
   - Add a new member to the `members` array:
   ```json
   {
     "uid": "UserB_UID_HERE",
     "role": "editor",
     "displayName": "User B",
     "email": "userb@example.com"
   }
   ```

3. **Log in as User B**:
   - The band will appear in User B's bands list
   - No need to use "Join Band" screen

---

## Issue 3: Spotify Not Configured Error

### Problem
You see "Spotify not configured" or "Premium required" error.

### Note: Credentials Are Pre-configured

Spotify API credentials are **pre-configured** for development. If you're seeing this error, check the following:

### Solutions

1. **Check Credentials**:
   ```dart
   // Add this debug print in spotify_service.dart
   print('Client ID: ${_clientId}');
   print('Spotify configured: ${SpotifyService.isConfigured}');
   // Should print your actual ID, not empty or 'your_client_id_here'
   ```

2. **Verify Spotify Premium**:
   - The account associated with your API app must have Spotify Premium
   - Free accounts can't access audio features

3. **Check API Rate Limits**:
   - Free tier: 100 requests per 2 seconds
   - If exceeded, wait a few seconds and try again

4. **Verify Web Config (for web deployment)**:
   - Check that `web/config.js` contains valid credentials
   - Open Chrome DevTools Console and type: `console.log(window.env)`
   - Should show your Client ID and Secret

5. **Clear Browser Cache**:
   - Sometimes old config.js is cached
   - Hard refresh: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (Mac)

---

## Issue 4: .env File Not Loading on Web

### Status: ✅ FIXED

This was fixed in the latest update. The app now:
1. Tries to load `.env` file
2. Falls back to `web/config.js` if `.env` not found
3. Shows a debug message instead of crashing

---

## Debugging Tips

### Check if Spotify is Configured

Add this to any screen to debug:
```dart
print('Spotify configured: ${SpotifyService.isConfigured}');
print('Client ID: ${dotenv.env['SPOTIFY_CLIENT_ID']}');
```

### Check Firestore Data

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project → Firestore Database
3. Browse collections to verify data structure

### Check App Logs

```bash
# Run with verbose logging
flutter run -d chrome --verbose

# Or view Chrome DevTools
# Press F12 in Chrome → Console tab
```

---

## Contact / Support

If issues persist:
1. Check the [ENV_SETUP.md](ENV_SETUP.md) guide
2. Review Firebase Console for errors
3. Verify Spotify Developer Dashboard settings
4. Check Chrome DevTools console for error messages

---

**Last Updated:** February 19, 2026  
**Version:** 1.1
