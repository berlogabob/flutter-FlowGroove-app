# 🔍 Firebase Analytics Troubleshooting Guide

**Date:** March 11, 2026  
**Status:** Debugging in progress

---

## 📊 Current Configuration

### Firebase Project
- **Project ID:** repsync-app-8685c
- **Project Number:** 703941154390
- **Measurement ID:** G-DQC026CRM8

### Web App Configuration
```dart
apiKey: AIzaSyAxQ53DQzyEkKXjo3Ry2B9pcTMvcyk4d5o
appId: 1:703941154390:web:43dfeaf2f6a0495e004df7
measurementId: G-DQC026CRM8
```

---

## 🛠️ Fixes Applied

### 1. Added Analytics Debug Utility
**File:** `lib/utils/analytics_debug.dart`

**Features:**
- ✅ Debug mode logging
- ✅ Connection testing
- ✅ Event logging with console output
- ✅ Screen view tracking

### 2. Updated main.dart
**Changes:**
- ✅ Import analytics debug utility
- ✅ Enable debug mode on startup
- ✅ Test analytics connection automatically
- ✅ Log all events to console

### 3. Updated home_screen.dart
**Changes:**
- ✅ Use AnalyticsDebug utility
- ✅ Double logging for verification

---

## 🔍 How to Test Analytics

### Step 1: Run the App in Debug Mode

```bash
# Run on Chrome (web)
flutter run -d chrome

# Or run on web with debug flag
flutter run -d chrome --debug
```

### Step 2: Check Console Output

You should see:
```
📊 Firebase Analytics initialized
📊 Analytics collection enabled
📊 Analytics Debug Mode: ENABLED
🔍 Testing Firebase Analytics Connection...
✅ Analytics instance created
✅ Analytics collection enabled
✅ Session timeout set to 30 seconds
✅ Test event logged: analytics_test
📱 App Instance ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
🎉 Analytics Test COMPLETE
```

### Step 3: Check Firebase Console

#### Realtime View (updates every 30 seconds)
1. Go to: https://console.firebase.google.com/project/repsync-app-8685c/analytics/realtime
2. You should see active users
3. Events appear within 30 seconds

#### Debug View (for development)
1. Go to: https://console.firebase.google.com/project/repsync-app-8685c/analytics/debugview
2. Enable debug mode on device (already enabled in code)
3. Events appear in real-time

---

## ⚠️ Common Issues & Solutions

### Issue 1: No Data in Realtime View

**Possible Causes:**
1. Analytics not initialized
2. Collection disabled
3. Wrong Measurement ID
4. Data delay (24-48 hours for reports)

**Solutions:**
```bash
# 1. Check console for initialization logs
flutter run -d chrome

# 2. Verify Measurement ID matches
# In lib/firebase_options.dart:
measurementId: 'G-DQC026CRM8'

# 3. Check Firebase Console
# https://console.firebase.google.com/project/repsync-app-8685c/analytics
```

### Issue 2: Events Not Showing

**Check:**
1. ✅ Analytics collection enabled
2. ✅ Debug mode enabled
3. ✅ Internet connection
4. ✅ Firebase initialized before logging

**Debug Code:**
```dart
// In main.dart - already added
AnalyticsDebug.enableDebugMode();
AnalyticsDebug.testConnection();

// Check console for:
// ✅ Test event logged: analytics_test
```

### Issue 3: Data Shows in Realtime but Not in Reports

**This is normal!**
- **Realtime:** Updates every 30 seconds
- **Standard Reports:** 24-48 hour delay
- **Debug View:** Real-time for development

**Solution:**
- Use Realtime view for immediate testing
- Use Debug View for development
- Wait 24-48 hours for standard reports

### Issue 4: GA4 Property Not Linked

**Symptoms:**
- Firebase shows "No Analytics Data"
- Measurement ID missing

**Fix:**
1. Go to: https://console.firebase.google.com/project/repsync-app-8685c/analytics
2. Click "Link to Google Analytics"
3. Select or create GA4 property
4. Enable data sharing
5. Save

---

## 📊 Testing Checklist

### In App Console
- [ ] ✅ Firebase initialized
- [ ] ✅ Analytics collection enabled
- [ ] ✅ Debug mode enabled
- [ ] ✅ Test event logged
- [ ] ✅ App Instance ID shown
- [ ] ✅ Screen views logged
- [ ] ✅ Login events logged

### In Firebase Console (Realtime)
- [ ] Active users count > 0
- [ ] Events appearing every 30 seconds
- [ ] Screen views showing
- [ ] Login events showing

### In Firebase Console (Debug View)
- [ ] Events appearing in real-time
- [ ] Screen views with parameters
- [ ] User properties set correctly

---

## 🎯 Event Types Being Tracked

### Automatic Events
- ✅ `app_open` - When app starts
- ✅ `session_start` - When session begins
- ✅ `user_engagement` - Time spent in app

### Manual Events
- ✅ `login` - User logs in (login_screen.dart)
- ✅ `screen_view` - Screen navigation (home_screen.dart)
- ✅ `analytics_test` - Test event (main.dart)

### Custom Events
- ✅ `app_version` - App version tracking
- ✅ `feature_usage` - Feature interactions

---

## 🔧 Debug Commands

### Enable Verbose Logging
```dart
// Already enabled in main.dart
AnalyticsDebug.enableDebugMode();
```

### Test Analytics Connection
```dart
// Automatically runs on app start
AnalyticsDebug.testConnection();
```

### Manual Event Test
```dart
// Add to any screen for testing
AnalyticsDebug.logEvent(
  name: 'test_event',
  parameters: {'test': true, 'timestamp': DateTime.now()},
);
```

---

## 📱 Platform-Specific Notes

### Web
- ✅ Measurement ID required
- ✅ Uses gtag.js internally
- ⚠️ Ad blockers may block analytics
- ⚠️ Browser privacy settings may limit tracking

### Android
- ✅ Google Play Services handles analytics
- ✅ More reliable than web
- ✅ Works offline (queues events)

### iOS
- ✅ Requires GoogleAppMeasurement
- ✅ ATT (App Tracking Transparency) may limit data
- ✅ IDFA restrictions apply

---

## 🚀 Next Steps

### Immediate
1. ✅ Run app in debug mode
2. ✅ Check console for test event
3. ✅ Check Firebase Realtime view
4. ✅ Verify Debug View shows events

### Short-term
1. Add more event tracking
2. Set up conversion goals
3. Create custom audiences
4. Configure funnel analysis

### Long-term
1. Set up BigQuery export
2. Create custom reports
3. Integrate with Google Ads
4. A/B testing setup

---

## 📞 Quick Reference

### Firebase Console
- **Project:** https://console.firebase.google.com/project/repsync-app-8685c
- **Analytics:** https://console.firebase.google.com/project/repsync-app-8685c/analytics
- **Realtime:** https://console.firebase.google.com/project/repsync-app-8685c/analytics/realtime
- **Debug View:** https://console.firebase.google.com/project/repsync-app-8685c/analytics/debugview

### Google Analytics
- **GA4 Property:** Link via Firebase Console
- **Reports:** Via Firebase or GA4 Console

---

## 🎯 Success Criteria

Analytics is working when:
- [ ] Console shows "Analytics Test COMPLETE"
- [ ] Realtime view shows active users
- [ ] Debug View shows events in real-time
- [ ] Screen views are tracked
- [ ] Login events are tracked
- [ ] App Instance ID is generated

---

**Last Updated:** March 11, 2026  
**Version:** 0.13.1+147  
**Status:** 🔍 Debugging Active
