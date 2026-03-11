# Android Auth Persistence Debug Guide

## Problem
After closing app on Android, user is removed and needs to login again.

## Current Implementation
✅ Firebase Auth persistence set to LOCAL before initialization
✅ Enhanced logging added to track auth state
✅ Package name matches google-services.json

## Testing Instructions

### Step 1: Install APK on Android device
```bash
# Connect device via USB
adb devices

# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Step 2: Login to app
- Open RepSync app
- Login with email/password
- Verify you can access the app

### Step 3: Close app completely
- Press home button (don't just minimize)
- Wait 5 seconds
- OR swipe away from recent apps

### Step 4: Check logs BEFORE reopening app
```bash
# Clear old logs
adb logcat -c

# Reopen app
# Then immediately check logs:
adb logcat | grep -i "auth\|firebase"
```

### Step 5: Expected log output
```
✅ Firebase Auth persistence set to LOCAL
🔍 Persistence verification: Setting LOCAL persistence confirmed
✅ Firebase initialized with auth persistence
🔑 AUTH RESTORED: User <email> found from previous session
   UID: <uid>
   Email verified: <true/false>
🔑 Auth Event: AUTH_RESTORED - email=<email>
🟢 Auth state: DATA - user=<email>
```

### Step 6: If user is NOT restored
Check for these logs:
```
🔑 NO USER: No user found from previous session
```

This means Firebase is NOT persisting the auth state.

## Possible Causes & Solutions

### Cause 1: App data cleared
**Symptom:** User not restored, no auth logs
**Solution:** Check if app data is being cleared on exit
```bash
adb shell pm list packages | grep rep sync
```

### Cause 2: Firebase not initialized correctly
**Symptom:** No "Firebase initialized" log
**Solution:** Check Firebase project configuration

### Cause 3: Persistence not supported on Android
**Symptom:** Warning about persistence already set
**Solution:** Android uses LOCAL by default, might not need explicit set

### Cause 4: App process killed immediately
**Symptom:** No logs at all on app restart
**Solution:** Check Android memory settings, disable "Don't keep activities"

## Debug Commands

### Check if user is persisted in Firebase
```bash
adb shell run-as com.example.flutter_repsync_app ls -la /data/data/com.example.flutter_repsync_app/
```

### View all Firebase logs
```bash
adb logcat | grep -E "Firebase|Auth|persistence"
```

### Check app lifecycle
```bash
adb shell dumpsys activity activities | grep -A 5 flutter_repsync
```

### Verify google-services.json is loaded
```bash
adb shell run-as com.example.flutter_repsync_app cat /data/data/com.example.flutter_repsync_app/files/google-services.json
```

## Test Scenarios

### Scenario 1: Background/Foreground
1. Login
2. Press home (background app)
3. Wait 10 seconds
4. Open from recent apps
5. **Expected:** User still logged in

### Scenario 2: Full Close
1. Login
2. Swipe away from recent apps
3. Wait 10 seconds
4. Open app from launcher
5. **Expected:** User still logged in

### Scenario 3: Device Restart
1. Login
2. Restart device
3. Open app
4. **Expected:** User still logged in

## Next Steps

1. **Run test on device** with `adb logcat`
2. **Capture logs** from app startup
3. **Share logs** to diagnose issue
4. **Check Firebase Console** for Android app configuration

---

**Updated:** February 26, 2026 15:30
**Status:** Debugging in progress
