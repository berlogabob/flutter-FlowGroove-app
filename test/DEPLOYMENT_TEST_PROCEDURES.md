# Phase 3 P1: Deployment Test Procedures

## Overview
This document describes test procedures for deployment scenarios. Full execution may require credentials and access to deployment targets.

---

## 3.6 FTP Deployment Test (`make deploy-stable`)

### Purpose
Test FTP deployment to stable environment (flowgroove.app)

### Prerequisites
- FTP credentials in `.env` file:
  ```bash
  FTP_HOST=194.39.124.68
  FTP_USER=sounding
  FTP_PASS=<your_password>
  FTP_DIR=flowgroove.app
  ```
- `lftp` installed: `brew install lftp`

### Test Procedure
```bash
# 1. Build Flutter web release
flutter build web --release

# 2. Generate web config from .env
./scripts/inject-web-config.sh

# 3. Run deployment
make deploy-stable

# 4. Verify deployment
curl -I https://flowgroove.app
# Expected: HTTP 200 OK

# 5. Check config.js is loaded
curl https://flowgroove.app/config.js
# Expected: window.env object with actual values (not placeholders)

# 6. Verify Firebase initializes
# Open browser console at https://flowgroove.app
# Expected: No Firebase configuration errors
```

### Success Criteria
- ✅ Build completes without errors
- ✅ FTP upload completes successfully
- ✅ Site loads without errors
- ✅ Firebase initializes correctly
- ✅ No console errors related to configuration

### Rollback Procedure
```bash
# If deployment fails, restore previous version:
# 1. Keep backup of previous build
cp -r build/web build/web.backup

# 2. Restore from backup
rm -rf build/web
cp -r build/web.backup build/web

# 3. Redeploy
make deploy-stable
```

---

## 3.7 GitHub Pages Test Deployment (`make deploy-test`)

### Purpose
Test deployment to GitHub Pages for staging/testing

### Prerequisites
- GitHub Pages enabled for repository
- `gh-pages` npm package: `npm install -g gh-pages`

### Test Procedure
```bash
# 1. Build Flutter web release
flutter build web --release

# 2. Generate web config
./scripts/inject-web-config.sh

# 3. Deploy to GitHub Pages
make deploy-test

# 4. Wait for GitHub Pages to propagate (~1-2 minutes)

# 5. Verify deployment
curl -I https://<username>.github.io/flutter_repsync_app/
# Expected: HTTP 200 OK

# 6. Check app loads
open https://<username>.github.io/flutter_repsync_app/
```

### Success Criteria
- ✅ Build completes without errors
- ✅ GitHub Pages deployment succeeds
- ✅ Site accessible via GitHub Pages URL
- ✅ App functions correctly

### Notes
- GitHub Pages has a propagation delay
- Base href may need adjustment in `index.html`

---

## 3.8 Android Release Test (`make release`)

### Purpose
Build and validate Android APK

### Prerequisites
- Android SDK configured
- Keystore for signing (release builds)
- `key.properties` configured in `android/` directory

### Test Procedure
```bash
# 1. Build Android release APK
make release

# 2. Verify APK created
ls -la build/app/outputs/flutter-apk/app-release.apk
# Expected: APK file exists, ~20-50MB

# 3. Verify APK doesn't contain web config
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep config.js
# Expected: No results (config.js should NOT be in APK)

# 4. Verify APK doesn't contain .env
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep "\.env"
# Expected: No results

# 5. Install on test device
adb install build/app/outputs/flutter-apk/app-release.apk

# 6. Launch app and verify Firebase initializes
# Check logcat for Firebase initialization
adb logcat | grep -i firebase
```

### Success Criteria
- ✅ APK builds successfully
- ✅ APK is signed correctly
- ✅ APK does NOT contain web/config.js
- ✅ APK does NOT contain .env files
- ✅ App launches without errors
- ✅ Firebase initializes from .env (mobile)

### Verification Commands
```bash
# Check APK contents
unzip -l build/app/outputs/flutter-apk/app-release.apk | head -50

# Verify signing
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk

# Check for web-specific files (should NOT be present)
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -E "config\.js|window\.env"
```

---

## 3.10 Rollback Procedure Test

### Purpose
Validate rollback process for emergency situations

### Test Scenario
Simulate rollback to previous version

### Test Procedure
```bash
# 1. Create a backup tag (before making changes)
git tag backup-before-config-modernization

# 2. Make some changes (simulate deployment)
echo "test change" >> CHANGELOG.md
git add CHANGELOG.md
git commit -m "Test change"

# 3. Verify change exists
git log -1 --oneline
# Expected: Shows "Test change" commit

# 4. Perform rollback
git stash  # Save current changes (if any)
git checkout backup-before-config-modernization  # Restore backup

# 5. Verify rollback successful
git log -1 --oneline
# Expected: Shows commit before "Test change"

# 6. Restore to latest (after test)
git checkout main
git pull origin main
```

### Success Criteria
- ✅ Backup tag created successfully
- ✅ Rollback to tag works
- ✅ App state matches backup point
- ✅ Can return to latest version

### Emergency Rollback Checklist
- [ ] Identify the backup tag/commit to restore
- [ ] Notify team of rollback
- [ ] Execute rollback: `git checkout <backup-tag>`
- [ ] Redeploy from backup
- [ ] Verify app functionality
- [ ] Document incident

---

## 3.5 Local Build with Environment Variables Test

### Purpose
Test CI/CD mode simulation with environment variables

### Test Procedure
```bash
# 1. Set environment variables (CI/CD mode)
export FIREBASE_API_KEY=test_key_123
export SPOTIFY_CLIENT_ID=test_spotify_id
export SPOTIFY_CLIENT_SECRET=test_secret
export TWITTER_API_KEY=test_twitter_key
export TWITTER_API_SECRET=test_twitter_secret

# 2. Generate web config (CI/CD mode)
./scripts/generate-web-config.sh

# 3. Verify config.js created
cat web/config.js

# 4. Verify values are injected
grep "test_key_123" web/config.js
# Expected: Found

grep "test_spotify_id" web/config.js
# Expected: Found

# 5. Clean up environment variables
unset FIREBASE_API_KEY
unset SPOTIFY_CLIENT_ID
unset SPOTIFY_CLIENT_SECRET
unset TWITTER_API_KEY
unset TWITTER_API_SECRET

# 6. Verify config.js NOT committed
git status
# Expected: config.js shown as untracked
```

### Success Criteria
- ✅ Environment variables are read correctly
- ✅ config.js generated with correct values
- ✅ No placeholders remain in config.js
- ✅ config.js is NOT tracked by git

---

## Test Execution Summary

| Test | Type | Executable | Status |
|------|------|------------|--------|
| 3.6 FTP Deployment | Manual | `make deploy-stable` | ⚠️ Requires credentials |
| 3.7 GitHub Pages | Manual | `make deploy-test` | ⚠️ Requires setup |
| 3.8 Android Release | Manual | `make release` | ⚠️ Requires keystore |
| 3.10 Rollback | Manual | Git commands | ✅ Can be tested |
| 3.5 Env Var Build | Manual | Shell commands | ✅ Can be tested |

---

## Notes

### Security Reminders
- NEVER commit `.env` or `web/config.js` to git
- Always use `.env.example` as template
- Rotate credentials if accidentally exposed
- Use `.gitignore` verification before commits

### CI/CD Integration
For automated pipelines:
1. Set environment variables in CI/CD secrets
2. Use `generate-web-config.sh` in build step
3. Deploy generated artifacts
4. Never store credentials in build artifacts

### Monitoring
After deployment, monitor:
- Firebase Analytics for initialization events
- Error reporting for configuration-related crashes
- Performance metrics for app startup time
