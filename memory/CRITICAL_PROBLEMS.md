# 🔴 CRITICAL PROBLEMS - NEVER AGAIN

**Rule:** Read before ANY code change!
**Last Updated:** April 9, 2026
**Branch:** second01
**Version:** 0.13.4+183

---

## 27. Missing foundation.dart Import Causes Metronome Crash

**Date:** 2026-04-09
**Severity:** 🔴 **CRITICAL**
**Status:** ✅ FIXED

### The Problem
When adding wakelock integration to `metronome_provider.dart`, the code uses `debugPrint()` from `package:flutter/foundation.dart` — but the import wasn't added. On emulator build (fresh compile), this caused a crash when tapping metronome Play:
```
NoSuchMethodError: The getter 'kDebugMode' was called on null
```

### Why It Happened
- File previously had no `foundation.dart` dependencies
- Adding `WakelockController` (which calls `debugPrint`) introduced `kDebugMode` usage
- Host Dart analyzer had cached imports, so it didn't catch the missing import
- Only failed on fresh emulator build

### The Fix
```dart
import 'package:flutter/foundation.dart'; // MUST be present when using debugPrint, kDebugMode, compute
```

### Rule: ALWAYS check imports when adding debugPrint/kDebugMode
When editing ANY file that uses these APIs, verify the import exists:
- `debugPrint()` → needs `package:flutter/foundation.dart`
- `kDebugMode` → needs `package:flutter/foundation.dart`
- `compute()` → needs `package:flutter/foundation.dart`

**Quick check after edits:**
```bash
flutter analyze lib/providers/data/metronome_provider.dart
# Must show 0 errors
```

### Prevention
- After adding new service imports (like wakelock_controller.dart), re-run `flutter analyze` on the modified file
- Don't trust cached analyzer results — always do a fresh check
- Test on emulator after significant changes, not just host machine

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

### The Fix
```dart
// ✅ CORRECT - Skip analytics on web
FirebaseAnalytics? analytics;
if (!kIsWeb) {
  analytics = FirebaseAnalytics.instance;
  // ... analytics setup
} else {
  debugPrint('ℹ️  Web platform - skipping Analytics initialization');
}
```

---

## 3. Web Config Not Loading (dart:js Interop Issue)

**Date:** 2026-04-02
**Severity:** 🔴 **CRITICAL**
**Status:** ✅ FIXED

### The Problem
After Flutter 3.41 web compiler update, `dart:js` interop broke:
```
NoSuchMethodError: method not found: '[]'
Receiver: Instance of 'minified:CA'
Arguments: ["env"]
```

**Impact:** App couldn't read `window.env`, showed "Firebase API key not configured" error

### Root Cause
```dart
// ❌ WRONG - Doesn't work with Flutter 3.41+ web compiler
final env = js.context['window']['env'];
```

The new dart2js compiler minifies JS objects, breaking `[]` operator access.

### The Fix
```dart
// ✅ CORRECT - Access window.env directly
import 'dart:js' as js;

String getWebConfig(String key) {
  final windowObj = js.context;  // Global context is window
  final env = windowObj['env'];  // Access env property
  if (env == null) return '';
  return env[key].toString();
}
```

### Files Involved
- `lib/services/api/web_config.web.dart` - Web config accessor
- `lib/config/env_config.dart` - Config validation
- `web/index.html` - Config script tag
- `web/config.demo.js` - Demo configuration (committed to git)
- `docs/config.js` - Deployed configuration (committed to git)

### Prevention Checklist
- [ ] Always test web config loading after Flutter updates
- [ ] Add debug logging in `getWebConfig()` for troubleshooting
- [ ] Verify `window.env` in browser console during testing
- [ ] Keep `web/config.demo.js` with valid Firebase key for testing
- [ ] Ensure `<script src="config.js">` loads BEFORE `flutter_bootstrap.js`

### Configuration Architecture (Current - WORKING)

```
┌─────────────────────────────────────────────────────────┐
│  Web Deployment (GitHub Pages / FTP)                    │
├─────────────────────────────────────────────────────────┤
│  1. web/config.demo.js (source, committed)              │
│  2. Copied to docs/config.js during deploy              │
│  3. Loaded in index.html: <script src="config.js">      │
│  4. Accessed via dart:js: js.context['env']             │
│  5. Firebase initialized with window.env.FIREBASE_API_KEY │
└─────────────────────────────────────────────────────────┘

✅ NO .env FILE NEEDED FOR WEB TESTING!
✅ Demo config uses public Firebase key (safe to commit)
✅ Spotify/Twitter disabled in demo (add credentials later if needed)
```

### Testing Commands
```bash
# Deploy to GitHub Pages (no credentials needed)
make deploy-test

# Verify config.js is live
curl https://berlogabob.github.io/flutter-FlowGroove-app/config.js

# Check in browser console
window.env  # Should show config object with FIREBASE_API_KEY
```

### Related Memory
- `SECURITY_BEST_PRACTICES.md` - Firebase key security
- `MAKEFILE_MODERNIZATION_COMPLETE.md` - Deployment workflow
- `FINAL_SUMMARY.md` - Complete modernization report

---

## 4. GitHub Pages Deploying to Wrong Branch

**Date:** 2026-04-02
**Severity:** 🟡 **MEDIUM**
**Status:** ✅ FIXED

### The Problem
GitHub Actions workflow deployed to `gh-pages` branch, but GitHub Pages was configured to serve from `docs/` folder on `second01` branch.

**Impact:** config.js was 404, app couldn't load Firebase config

### The Fix
1. Deleted `gh-pages` branch
2. Removed GitHub Actions workflow (`.github/workflows/deploy-test.yml`)
3. Use `make deploy-test` which deploys to `docs/` folder

### Prevention Checklist
- [ ] Verify GitHub Pages source in repository settings
- [ ] Ensure deployment script targets correct branch/folder
- [ ] Test config.js accessibility after deploy: `curl <url>/config.js`
- [ ] Don't mix deployment methods (Actions + Makefile)

---

## 5. docs/config.js in .gitignore

**Date:** 2026-04-02
**Severity:** 🟡 **MEDIUM**
**Status:** ✅ FIXED

### The Problem
`/docs/config.js` was in `.gitignore`, preventing it from being committed to git.

**Impact:** GitHub Pages served 404 for config.js, app couldn't load Firebase config

### The Fix
Removed `/docs/config.js` from `.gitignore`:
```gitignore
# ✅ CORRECT - Keep web/config.js ignored (generated locally)
web/config.js

# ✅ REMOVE this line - docs/config.js needs to be committed
# /docs/config.js  ← REMOVED!
```

### Why docs/config.js Must Be Committed
- GitHub Pages serves from `docs/` folder
- config.js contains Firebase config (public key, safe to commit)
- Without it, web app can't initialize Firebase

### Prevention Checklist
- [ ] Never ignore `docs/config.js` (must be deployed)
- [ ] DO ignore `web/config.js` (generated during build)
- [ ] Verify with `git status` before pushing
- [ ] Test: `git ls-tree docs/ | grep config.js` should show file

---

## 6. No Global Error Widget Handler (RESOLVED)

**Date:** 2026-04-08
**Severity:** 🟡 MEDIUM
**Status:** ✅ FIXED

### The Problem
QWEN.md documented "Add `ErrorWidget.builder` for graceful degradation" as a key learning, but `main.dart` never set a global error widget builder. Unhandled widget errors showed full Flutter red screen instead of graceful fallback.

### The Fix
- Added `ErrorWidget.builder` in `main.dart` during initialization
- Shows themed error message with icon and details (debug mode shows full exception)
- Uses MonoPulseTheme colors for consistency
- Logs errors to debug console for development

### Prevention
- [ ] Never remove `ErrorWidget.builder` from `main.dart`
- [ ] All widget errors should be graceful, not crash the app
- [ ] Test error scenarios: malformed data, missing assets, network failures

---

## 7. Memory Bank 75% Missing (RESOLVED)

**Date:** 2026-04-08
**Severity:** 🟡 MEDIUM
**Status:** ✅ FIXED

### The Problem
`memory/README.md` referenced 4 memory files but only `CRITICAL_PROBLEMS.md` existed. Three critical files were missing:
- `SECURITY_ISSUES.md`
- `BUILD_DEPLOYMENT_ISSUES.md`
- `DEPENDENCY_ISSUES.md`

### The Fix
- Created all 3 missing memory files with documented issues
- Populated with relevant historical issues from project history
- Added prevention checklists to each file

### Prevention
- [ ] Memory bank files must exist before agents reference them
- [ ] Run periodic audit: check all referenced memory files exist
- [ ] New issues should be documented immediately, not "later"

---

## 8. Editor Temp Files in Source Directory (RESOLVED)

**Date:** 2026-04-08
**Severity:** 🟢 LOW
**Status:** ✅ FIXED

### The Problem
Editor auto-save file `.!15526!analytics_debug.dart` found in `lib/utils/`. These files can confuse code analysis tools and may be accidentally committed.

### The Fix
- Deleted all temp files from source directories
- Added editor temp file patterns to `.gitignore`
- Added `site/public/` (Hugo build output) to `.gitignore`
- Added `web/config.js` (generated file) to `.gitignore`

### Prevention
- [ ] Configure editor to save temp files outside project directory
- [ ] Run `git status` before committing to catch stray files
- [ ] `.gitignore` patterns: `.*!`, `!*~`, `\#*\#`

---

## Summary: Current Working Configuration

### ✅ What Works Now

| Component | Status | Notes |
|-----------|--------|-------|
| **Web Config Loading** | ✅ Working | `dart:js` fixed for Flutter 3.41 |
| **Firebase Initialization** | ✅ Working | Uses `window.env.FIREBASE_API_KEY` |
| **GitHub Pages Deploy** | ✅ Working | `docs/` folder on `second01` branch |
| **Demo Config** | ✅ Working | `web/config.demo.js` with public Firebase key |
| **No .env Required** | ✅ Working | Test deploys work without credentials |
| **Spotify/Twitter** | ⚠️ Disabled | Add credentials later if needed |

### 🚀 Deployment Commands

```bash
# Test deployment (no credentials needed)
make deploy-test

# Production deployment (requires FTP credentials)
export FTP_PASS=your_password
make deploy-stable

# Android build (no credentials needed)
make release
```

### 📚 Documentation

- `DEPLOYMENT_GUIDE.md` - Full deployment instructions
- `docs/MAKEFILE_MODERNIZATION_COMPLETE.md` - Makefile reference
- `docs/FINAL_SUMMARY.md` - Modernization summary
- `docs/SECURITY_BEST_PRACTICES.md` - Security guidelines
- `docs/ROLLBACK_PROCEDURE.md` - Emergency rollback
- `README.md` - Quick start guide

---

**Last Verified:** April 8, 2026
**Version:** 0.13.4+183
**Status:** ✅ ALL SYSTEMS WORKING
