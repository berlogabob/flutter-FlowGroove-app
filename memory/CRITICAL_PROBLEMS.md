# 🔴 CRITICAL PROBLEMS - NEVER AGAIN

**Rule:** Read before ANY code change!  
**Last Updated:** March 14, 2026  
**Branch:** second01

---

## 1. .env File Bundled in Web Build

**Date:** 2026-03-14  
**Severity:** 🔴 **CRITICAL**  
**Status:** ✅ FIXED

### The Problem
`.env` was added to `pubspec.yaml` assets, causing it to be:
- Bundled into `build/web/`
- Uploaded to FTP
- Made publicly accessible at `https://flowgroove.app/.env`
- **Exposed Firebase API keys, Spotify credentials, Twitter keys**

### Root Cause
```yaml
# ❌ WRONG!
assets:
  - .env
  - assets/sounds/
```

### The Fix
```yaml
# ✅ CORRECT
assets:
  - assets/sounds/
  - assets/icon.png
```

### Prevention Checklist
- [ ] Never add `.env` to assets section
- [ ] Verify before build: `find build/web -name "*.env*"` (must return empty)
- [ ] Test after deploy: `curl https://flowgroove.app/.env` (must return 404)
- [ ] Check `.gitignore` includes `.env`

### Files Involved
- `pubspec.yaml` - Assets configuration
- `.gitignore` - Exclusion rules

### Related Memory
- `SECURITY_ISSUES.md` - Security vulnerabilities
- `BUILD_DEPLOYMENT_ISSUES.md` - Deployment problems

---

## 2. Firebase Analytics on Web

**Date:** 2026-03-14  
**Severity:** 🔴 **CRITICAL**  
**Status:** ✅ FIXED (Disabled on web)

### The Problem
Firebase Analytics throws error on web:
```
PlatformException(channel-error, Unable to establish connection on channel: 
"dev.flutter.pigeon.firebase_analytics_platform_interface.FirebaseAnalyticsHostApi.setAnalyticsCollectionEnabled")
```

**Impact:** App crashes on web, white screen

### Root Cause
Firebase Analytics not supported on web in current configuration. Error thrown during initialization breaks app startup.

### The Fix
```dart
// ✅ CORRECT - Skip analytics on web
FirebaseAnalytics? analytics;
if (!kIsWeb) {
  analytics = FirebaseAnalytics.instance;
  await AnalyticsService.initialize();
  // ... rest of analytics setup
} else {
  debugPrint('ℹ️  Web platform - skipping Analytics initialization');
}
```

**File:** `lib/main.dart`

### Prevention Checklist
- [ ] Always check `kIsWeb` before Analytics initialization
- [ ] Make analytics nullable: `FirebaseAnalytics?`
- [ ] Use null-safe access: `analytics?.logLogin()`
- [ ] Test web build after ANY Firebase changes

### Files Involved
- `lib/main.dart` - Main entry point
- `lib/services/analytics_service.dart` - Analytics service

---

## 3. setPersistence on Web

**Date:** 2026-03-14  
**Severity:** 🔴 **CRITICAL**  
**Status:** ✅ FIXED

### The Problem
```
setPersistence() is only supported on web based platforms
Error: UNSUPPORTED_OS
TypeError: Instance of 'minified:LY': type 'minified:LY' is not a subtype of type 'minified:r'
```

**Impact:** White screen, app crash on web

### Root Cause
`FirebaseAuth.instance.setPersistence()` not supported on web. Must only be called on mobile platforms.

### The Fix
```dart
// ✅ CORRECT - Only call on mobile
if (!kIsWeb && firebaseOk) {
  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    debugPrint('✅ Auth persistence set to LOCAL');
  } catch (e) {
    debugPrint('⚠️  Auth persistence failed: $e');
  }
}
```

**File:** `lib/main.dart`

### Prevention Checklist
- [ ] Always wrap with `if (!kIsWeb)`
- [ ] Check Firebase initialized first: `firebaseOk`
- [ ] Use try-catch for safety
- [ ] Add debug logging

### Related Issues
- Firebase initialization must complete first
- Analytics also needs web check

---

## 4. FTP Deployment Doesn't Update Files

**Date:** 2026-03-14  
**Severity:** 🟠 **HIGH**  
**Status:** ✅ FIXED

### The Problem
Files on FTP not updating - old files remain with old timestamps. Build succeeds but deployed site shows old version.

**Impact:** Users see old version, fixes don't deploy

### Root Cause
lftp `mirror --reverse --delete --only-newer` only uploads newer files. If build produces same-size files, they're skipped.

### The Fix
```bash
# ✅ CORRECT - Delete all files first, then upload
lftp -c "
  set ftp:ssl-allow no
  open -u 'sounding','PASSWORD' 194.39.124.68
  cd flowgroove.app
  # Remove all existing files first
  rm -rf *
  # Upload fresh build
  mirror --reverse --delete build/web .
  bye
"
```

**File:** `scripts/deploy-all.sh`

### Prevention Checklist
- [ ] Always `rm -rf *` before upload
- [ ] Use `--delete` flag to remove old files
- [ ] Verify after deploy: `curl -I https://flowgroove.app/`
- [ ] Check timestamp: `last-modified` header should be recent

### Files Involved
- `scripts/deploy-all.sh` - Deployment script
- `scripts/deploy-to-flowgroove.sh` - FTP deployment

---

## 5. White Screen on Web (Multiple Causes)

**Date:** 2026-03-14  
**Severity:** 🔴 **CRITICAL**  
**Status:** ✅ FIXED

### The Problem
Web app shows white/gray screen, doesn't load. Console shows errors.

### Root Causes Found
1. Firebase Analytics initialization error
2. setPersistence error on web
3. .env file not found (403)
4. Missing files in build

### The Fix
```dart
// ✅ CORRECT - Comprehensive error handling
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with error handling
  bool firebaseOk = false;
  try {
    await Firebase.initializeApp(...);
    firebaseOk = true;
  } catch (e, stack) {
    debugPrint('❌ Firebase failed: $e');
  }
  
  // Skip analytics on web
  if (!kIsWeb && firebaseOk) {
    await AnalyticsService.initialize();
  }
  
  // Skip persistence on web
  if (!kIsWeb && firebaseOk) {
    await FirebaseAuth.instance.setPersistence(...);
  }
  
  runApp(...);
}
```

### Prevention Checklist
- [ ] Wrap ALL Firebase init in try-catch
- [ ] Check `kIsWeb` for platform-specific code
- [ ] Add debug logging at each step
- [ ] Test in incognito mode (no cache)
- [ ] Check browser console for errors

---

## 6. GitHub Pages Wrong base-href

**Date:** 2026-03-14  
**Severity:** 🟡 **MEDIUM**  
**Status:** ✅ UNDERSTOOD

### The Problem
Files load from wrong path:
```
GET https://flowgroove.app/flutter-repsync-app/main.dart.js 404
```

### Root Cause
Build with wrong `--base-href`:
```bash
# ❌ WRONG for flowgroove.app
flutter build web --base-href "/flutter-repsync-app/"

# ✅ CORRECT for flowgroove.app
flutter build web --base-href "/"
```

### Prevention Checklist
- [ ] Use `--base-href "/"` for flowgroove.app
- [ ] Use `--base-href "/flutter-FlowGroove-app/"` for GitHub Pages
- [ ] Check after build: `cat build/web/index.html | grep "base href"`
- [ ] Verify deployed site loads all resources

---

## 📊 Quick Reference

### Platform Checks
```dart
// Web-only code
if (kIsWeb) {
  // Web-specific
}

// Mobile-only code
if (!kIsWeb) {
  // Mobile-specific
}
```

### Build Commands
```bash
# For flowgroove.app (FTP)
flutter build web --release --base-href "/"

# For GitHub Pages
flutter build web --release --base-href "/flutter-FlowGroove-app/"
```

### Deployment Commands
```bash
# FTP with clean deploy
lftp -c "
  cd flowgroove.app
  rm -rf *
  mirror --reverse build/web .
"

# GitHub Pages
npx gh-pages -d build/web -b gh-pages
```

### Verification Commands
```bash
# Check .env not in build
find build/web -name "*.env*"

# Test deployed site
curl -I https://flowgroove.app/
curl https://flowgroove.app/.env  # Should 404

# Check base-href
cat build/web/index.html | grep "base href"
```

---

## 🎯 Working Version Reference

### Known Good Version
- **Commit:** `5ed6781` (Release 0.13.1+167)
- **Branch:** `backup/march-14-analytics-fix`
- **Current:** `second01` branch

### Key Files State
- `lib/main.dart` - Analytics disabled on web, nullable
- `pubspec.yaml` - No .env in assets
- `scripts/deploy-all.sh` - Clean FTP deploy

---

**Last Review:** March 14, 2026  
**Next Review:** Before EVERY code change  
**Maintained By:** Mr. Memory Agent (`agents/mr-memory.md`)
