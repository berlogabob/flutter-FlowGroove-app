# 🔒 SECURITY FIX: Environment Variables & Credentials

## Problem Summary

**Issue:** Firebase API key and other credentials were exposed in git repository through `assets/env.json`

**Root Cause:** 
- `assets/env.json` was committed to git (not in `.gitignore`)
- File was bundled into web builds via `pubspec.yaml` assets section
- Credentials became publicly accessible in deployed web builds

## What Was Fixed

### 1. Removed from Git Tracking ✅
```bash
git rm --cached assets/env.json docs/assets/assets/env.json
```

### 2. Added to .gitignore ✅
```
assets/env.json
```

### 3. Removed from pubspec.yaml ✅
```yaml
# BEFORE (insecure)
assets:
  - assets/env.json  # ← BUNDLED INTO WEB BUILDS!
  - assets/sounds/

# AFTER (secure)
assets:
  - assets/sounds/
  - assets/logo_clean.png
```

### 4. Created Secure Configuration Pattern ✅

#### For Mobile/Desktop (`.env` file)
- Copy `.env.example` to `.env`
- Fill in your credentials
- File is gitignored - never committed!

#### For Web (`web/config.js`)
- Copy `web/config.js.template` to `web/config.js`
- Fill in credentials
- Inject at deployment time (not bundled)
- Serve separately from build artifacts

### 5. Created Unified Config Loader ✅
New file: `lib/config/env_config.dart`
- Single source of truth for all environment variables
- Platform-specific loading (web vs mobile)
- Placeholder detection
- Easy to use: `env.spotifyClientId`

## Setup Instructions

### For Local Development (Mobile)

1. **Create your .env file:**
   ```bash
   cp .env.example .env
   ```

2. **Fill in credentials in `.env`:**
   ```
   FIREBASE_API_KEY=your_actual_key_here
   SPOTIFY_CLIENT_ID=your_client_id
   SPOTIFY_CLIENT_SECRET=your_client_secret
   ```

3. **Done!** The app will load from `.env` automatically

### For Web Deployment

1. **Create web/config.js:**
   ```bash
   cp web/config.js.template web/config.js
   ```

2. **Fill in credentials in `web/config.js`:**
   ```javascript
   window.env = {
     FIREBASE_API_KEY: 'your_actual_key_here',
     SPOTIFY_CLIENT_ID: 'your_client_id',
     // ... etc
   };
   ```

3. **Deploy config.js separately** (not in build folder)
   - Configure your web server to serve it
   - Or inject via deployment pipeline

4. **Build without bundled env:**
   ```bash
   flutter build web
   # env.json is NOT bundled anymore!
   ```

## Verification Checklist

Before deploying, ALWAYS run these checks:

### Pre-Deploy Security Scan
```bash
# 1. Check no env files in build
find build/web -name "*.env*" -o -name "env.json"
# Should return: (nothing)

# 2. Check no secrets in git
git ls-files | grep -E "(env\.json|\.env$)"
# Should return: .env.example (only!)

# 3. Check pubspec.yaml
grep -A 5 "assets:" pubspec.yaml
# Should NOT include: assets/env.json

# 4. Verify .gitignore
grep "assets/env.json" .gitignore
# Should return: assets/env.json
```

### Post-Deploy Verification
```bash
# 1. Check deployed site for secrets
curl https://your-app.com/.env
# Should return: 404 Not Found

curl https://your-app.com/assets/env.json
# Should return: 404 Not Found

# 2. Check browser console
# Open dev tools → Console
# Should NOT see any credential warnings
```

## Architecture

### How It Works

```
┌─────────────────────────────────────────┐
│         Mobile/Desktop Build            │
│  ┌─────────────────────────────────┐   │
│  │  .env file (gitignored)         │   │
│  │  - Loaded at runtime            │   │
│  │  - Never bundled                │   │
│  └─────────────────────────────────┘   │
│              ↓                          │
│  ┌─────────────────────────────────┐   │
│  │  EnvConfig (env_config.dart)    │   │
│  │  - Unified API                  │   │
│  │  - Placeholder detection        │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│           Web Build                     │
│  ┌─────────────────────────────────┐   │
│  │  web/config.js (not bundled)    │   │
│  │  - Injected at deploy time      │   │
│  │  - Served separately            │   │
│  └─────────────────────────────────┘   │
│              ↓                          │
│  ┌─────────────────────────────────┐   │
│  │  window.env (JS interop)        │   │
│  │  - Read at runtime              │   │
│  │  - Never in build artifacts     │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### File Locations

| File | Purpose | Git Status | Bundled? |
|------|---------|------------|----------|
| `.env` | Mobile credentials | ❌ Ignored | ❌ No |
| `.env.example` | Template | ✅ Tracked | ❌ No |
| `assets/env.json.template` | Template | ✅ Tracked | ❌ No |
| `assets/env.json` | Mobile config (old) | ❌ Removed | ❌ No |
| `web/config.js` | Web credentials | ❌ Ignored | ❌ No |
| `web/config.js.template` | Template | ✅ Tracked | ❌ No |
| `lib/config/env_config.dart` | Config loader | ✅ Tracked | ✅ Yes |

## Migration Guide

### If You're Using the Old Pattern

**Before:**
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
final key = dotenv.env['FIREBASE_API_KEY'];
```

**After:**
```dart
import '../../config/env_config.dart';
final key = env.firebaseApiKey;
```

### Benefits of New Pattern
- ✅ More secure (not bundled in web builds)
- ✅ Type-safe accessors
- ✅ Placeholder detection
- ✅ Unified API across platforms
- ✅ Easy to test (can mock `env`)

## Prevention: Never Let This Happen Again

### Pre-commit Hooks
Add to your `.git/hooks/pre-commit`:
```bash
#!/bin/bash
# Check for secrets in staged files
if git diff --cached --name-only | grep -qE "(env\.json|\.env$)"; then
  echo "❌ ERROR: Attempting to commit secret files!"
  git diff --cached --name-only | grep -E "(env\.json|\.env$)"
  exit 1
fi

# Check for common secret patterns
if git diff --cached | grep -qE "AIzaSy[0-9A-Za-z_-]{35}"; then
  echo "❌ ERROR: Firebase API key detected in changes!"
  exit 1
fi
```

### CI/CD Checks
Add to your deployment pipeline:
```yaml
# Example GitHub Actions step
- name: Security Scan
  run: |
    echo "Checking for exposed secrets..."
    ! grep -r "AIzaSy" build/web/ || (echo "Found Firebase key!" && exit 1)
    ! test -f build/web/assets/env.json || (echo "Found env.json!" && exit 1)
```

### Code Review Checklist
- [ ] No `assets/env.json` in pubspec.yaml
- [ ] No `.env` or `config.js` in git (except templates)
- [ ] Pre-deploy security scan passes
- [ ] Web build artifacts cleaned

## What To Do Now

### Immediate Actions (Within 24 Hours)

1. **Rotate Firebase API Key:**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Project Settings → General → Your apps
   - Generate new API key
   - Update all config files

2. **Update All Config Files:**
   ```bash
   # Mobile
   cp .env.example .env
   # Edit .env with new credentials
   
   # Web
   cp web/config.js.template web/config.js
   # Edit web/config.js with new credentials
   ```

3. **Force Push to Remove History:**
   ```bash
   # WARNING: This rewrites git history!
   # Make sure all team members pull --rebase
   
   git commit -m "chore: remove secrets from git tracking"
   git filter-branch --force --index-filter \
     'git rm --cached --ignore-unmatch assets/env.json docs/assets/assets/env.json' \
     --prune-empty --tag-name-filter cat -- --all
   git push origin --force --all
   ```

4. **Verify Deployment:**
   ```bash
   flutter clean
   flutter build web
   find build/web -name "*.env*" -o -name "env.json"
   # Should return: (nothing)
   ```

## Related Files

- `lib/config/env_config.dart` - New secure config loader
- `lib/services/api/web_config.web.dart` - Web JS interop
- `lib/services/api/web_config.stub.dart` - Non-web stub
- `lib/services/api/spotify_service.dart` - Updated to use EnvConfig
- `.env.example` - Template for .env file
- `web/config.js.template` - Template for web config
- `assets/env.json.template` - Template for mobile config

## Questions?

If you have questions about this fix:
1. Check `lib/config/env_config.dart` for usage examples
2. Review this document for setup instructions
3. Run verification checklist before deploying

---

**Date Fixed:** March 30, 2026  
**Fixed By:** Automated Security Fix  
**Review Status:** ⏳ Pending manual review
