# 🔴 CRITICAL PROBLEMS - NEVER AGAIN

**Rule:** Read before ANY code change!

---

## 1. .env File Bundled in Web Build

**Date:** 2026-03-14  
**Severity:** 🔴 **CRITICAL**  
**Status:** ✅ FIXED

### The Problem
`.env` was added to `pubspec.yaml` assets, causing it to be:
- Bundled into `build/web/`
- Uploaded to FTP
- Made publicly accessible

### Root Cause
```yaml
# WRONG!
assets:
  - .env
```

### The Fix
```yaml
# CORRECT
assets:
  - assets/sounds/
  - assets/icon.png
```

### Prevention
- [ ] Never add `.env` to assets
- [ ] Verify: `find build/web -name "*.env*"` (must be empty)
- [ ] Test: `curl https://flowgroove.app/.env` (must 404)

---

## 2. Firebase Analytics on Web

**Date:** 2026-03-14  
**Severity:** 🔴 **CRITICAL**  
**Status:** ✅ FIXED

### The Problem
Firebase Analytics throws error on web:
```
PlatformException(channel-error, Unable to establish connection on channel)
```

### Root Cause
Analytics not supported on web in current configuration

### The Fix
```dart
// Skip analytics on web
if (!kIsWeb) {
  await AnalyticsService.initialize();
}
```

### Prevention
- [ ] Always check `kIsWeb` before Analytics
- [ ] Test web build after Firebase changes

---

## 3. setPersistence on Web

**Date:** 2026-03-14  
**Severity:** 🟠 **HIGH**  
**Status:** ✅ FIXED

### The Problem
```
setPersistence() is only supported on web based platforms
Error: UNSUPPORTED_OS
```

### The Fix
```dart
// Only call on mobile
if (!kIsWeb) {
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
}
```

---

## 4. FTP Deployment Doesn't Update

**Date:** 2026-03-14  
**Severity:** 🟠 **HIGH**  
**Status:** ✅ FIXED

### The Problem
Files on FTP not updating - old files remain

### The Fix
```bash
# Delete all files first, then upload
lftp -c "
  cd flowgroove.app
  rm -rf *
  mirror --reverse build/web .
"
```

---

**Last Review:** March 14, 2026  
**Next Review:** Before every code change
