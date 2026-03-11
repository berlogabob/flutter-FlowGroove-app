# 🚀 FLOWGROOVE.APP DEPLOYMENT GUIDE

**Production URL:** https://flowgroove.app/  
**Backup URL:** https://berlogabob.github.io/flutter-FlowGroove-app/

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [FTP Setup](#ftp-setup)
3. [Deployment Commands](#deployment-commands)
4. [Release Workflow](#release-workflow)
5. [Troubleshooting](#troubleshooting)

---

## 🔐 Firebase Authorized Domains

✅ **Already configured:**
- `localhost` (development)
- `repsync-app-8685c.firebaseapp.com` (Firebase hosting)
- `repsync-app-8685c.web.app` (Firebase hosting)
- `berlogabob.github.io` (GitHub Pages backup)
- `flowgroove.app` (production) ✅
- `www.flowgroove.app` (production www) ✅

**No action needed** - Firebase Auth is already configured for all domains!

---

## 🛠️ FTP Setup

### Step 1: Create FTP Credentials File

```bash
# Copy the example file
cp .ftp-env.example .ftp-env

# Edit with your credentials
nano .ftp-env
```

### Step 2: Add Your FTP Credentials

Edit `.ftp-env` with your actual credentials:

```env
FTP_HOST=ftp.flowgroove.app
FTP_USER=your_actual_ftp_username
FTP_PASS=your_actual_ftp_password
REMOTE_DIR=public_html
```

**⚠️ SECURITY:** The `.ftp-env` file is in `.gitignore` - never commit it!

### Step 3: Install lftp (Recommended)

For faster deployments, install `lftp`:

```bash
# macOS
brew install lftp

# Ubuntu/Debian
sudo apt-get install lftp

# Fedora
sudo dnf install lftp
```

Without `lftp`, deployments will use `curl` (slower but works).

---

## 📦 Deployment Commands

### Quick Reference

| Command | Description |
|---------|-------------|
| `make deploy-stable` | Build + Deploy to flowgroove.app |
| `make deploy-flowgroove` | Deploy existing build to flowgroove.app |
| `make release-stable` | Full release + deploy to flowgroove.app |
| `make deploy` | Deploy to GitHub Pages (current branch) |
| `make release` | Full release + GitHub Pages |

---

### 1. Deploy Stable Version (Recommended)

**Builds and deploys to production:**

```bash
make deploy-stable
```

**What it does:**
1. ✅ Builds web app with correct base-href
2. ✅ Generates `version.json` with current version
3. ✅ Deploys to `flowgroove.app` via FTP
4. ✅ Copies build to `docs/` (backup)
5. ✅ Commits to git main branch
6. ✅ Pushes to GitHub

**Time:** ~2-5 minutes (depending on internet speed)

---

### 2. Deploy Existing Build (FTP Only)

**Use when you already have a build:**

```bash
make deploy-flowgroove
```

**What it does:**
1. ✅ Deploys `build/web/` to `flowgroove.app` via FTP
2. ✅ No build step (faster)

**Time:** ~1-2 minutes

---

### 3. Full Stable Release

**Complete release cycle for production:**

```bash
make release-stable
```

**What it does:**
1. ✅ Increments build number
2. ✅ Builds web, Android APK, and AAB
3. ✅ Validates agent system
4. ✅ Deploys to `flowgroove.app` via FTP
5. ✅ Creates GitHub Release with APK + AAB
6. ✅ Commits and tags release
7. ✅ Pushes to GitHub

**Time:** ~5-10 minutes

**Output:**
- Production: https://flowgroove.app/
- Android APK: `build/app/outputs/flutter-apk/app-release.apk`
- Android AAB: `build/app/outputs/bundle/release/app-release.aab`
- GitHub Release: https://github.com/berlogabob/flutter-FlowGroove-app/releases

---

### 4. GitHub Pages Deployment (Backup)

**Deploy to GitHub Pages only:**

```bash
make deploy
```

**Use for:** Testing, staging, or backup deployment

**Output:** https://berlogabob.github.io/flutter-FlowGroove-app/

---

## 🔄 Release Workflow

### Standard Release (Recommended)

```bash
# 1. Make your changes
git add .
git commit -m "Feature: amazing new feature"

# 2. Deploy to production
make release-stable
```

**Result:**
- ✅ Version incremented (e.g., 0.13.1+147 → 0.13.1+148)
- ✅ Deployed to https://flowgroove.app/
- ✅ GitHub Release created with APK + AAB
- ✅ Git tag created (e.g., v0.13.1+148)

---

### Quick Hotfix

```bash
# 1. Make urgent fix
git add .
git commit -m "Fix: critical bug fix"

# 2. Deploy without incrementing version
make deploy-flowgroove
```

**Use when:** You need to deploy immediately without version bump

---

### Testing Before Production

```bash
# 1. Build for testing
make build-web

# 2. Test locally
flutter run -d chrome

# 3. Deploy to GitHub Pages for staging
make deploy

# 4. Test at: https://berlogabob.github.io/flutter-FlowGroove-app/

# 5. If all good, deploy to production
make deploy-stable
```

---

## 🔍 Troubleshooting

### FTP Upload Fails

**Error:** `FTP credentials not set!`

**Solution:**
```bash
# Check if .ftp-env file exists
ls -la .ftp-env

# If not, create it
cp .ftp-env.example .ftp-env
nano .ftp-env  # Add your credentials
```

---

### Slow FTP Upload

**Symptom:** Upload takes >5 minutes

**Solution:** Install `lftp` for faster parallel uploads:

```bash
# macOS
brew install lftp

# Ubuntu/Debian
sudo apt-get install lftp
```

---

### Firebase Auth Error on flowgroove.app

**Error:** `auth/unauthorized-domain`

**Solution:**
1. Go to: https://console.firebase.google.com/project/repsync-app-8685c/authentication/providers
2. Click "Sign-in method" tab
3. Scroll to "Authorized domains"
4. Ensure `flowgroove.app` and `www.flowgroove.app` are listed
5. If not, click "Add domain" and add them

**✅ Already configured** - This should not happen!

---

### White Screen After Deployment

**Causes:**
1. Browser cache
2. Incorrect base-href
3. Missing assets

**Solutions:**

**1. Clear browser cache:**
- Hard refresh: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows)
- Or open in incognito mode

**2. Check base-href in deployed files:**
```bash
curl -s https://flowgroove.app/ | grep "base href"
# Should show: <base href="/" />
```

**3. Rebuild and redeploy:**
```bash
make build-web
make deploy-flowgroove
```

---

### Version Not Showing Correctly

**Symptom:** Profile screen shows old version

**Solution:**
```bash
# Rebuild with fresh version.json
flutter clean
make build-web

# Verify version.json
cat build/web/version.json

# Redeploy
make deploy-flowgroove
```

---

### lftp Connection Timeout

**Error:** `Connection timeout`

**Solutions:**
1. Check FTP credentials are correct
2. Verify FTP host is reachable:
   ```bash
   ping ftp.flowgroove.app
   ```
3. Try passive mode (already configured in script)
4. Contact hosting provider if FTP server is down

---

## 📊 Deployment Checklist

### Before Production Release

- [ ] All tests passing (`make test`)
- [ ] No analyzer errors (`make analyze`)
- [ ] Tested on GitHub Pages staging
- [ ] Version number is correct
- [ ] CHANGELOG.md updated
- [ ] FTP credentials configured

### After Production Release

- [ ] Test login on https://flowgroove.app/
- [ ] Test main features work
- [ ] Check browser console for errors
- [ ] Verify version in profile screen
- [ ] Test on mobile devices
- [ ] Monitor Firebase Analytics

---

## 🎯 Best Practices

### 1. Always Test on Staging First

```bash
# Deploy to GitHub Pages for testing
make deploy

# Test at: https://berlogabob.github.io/flutter-FlowGroove-app/

# If all good, deploy to production
make deploy-stable
```

### 2. Use Release-Stable for Major Versions

```bash
# For major releases with new features
make release-stable
```

### 3. Use Deploy-Flowgroove for Hotfixes

```bash
# For urgent bug fixes
make deploy-flowgroove
```

### 4. Keep Git Clean

```bash
# Commit before deployment
git add .
git commit -m "Fix: critical bug"

# Deploy
make deploy-stable
```

### 5. Monitor After Deployment

- Check Firebase Analytics Realtime
- Monitor error logs
- Test critical user flows

---

## 📞 Support

**Issues?**
1. Check this guide's [Troubleshooting](#troubleshooting) section
2. Review Firebase Console: https://console.firebase.google.com/project/repsync-app-8685c
3. Check GitHub Actions for deployment status

**Firebase Console:**
- Authentication: https://console.firebase.google.com/project/repsync-app-8685c/authentication
- Hosting: https://console.firebase.google.com/project/repsync-app-8685c/hosting
- Analytics: https://console.firebase.google.com/project/repsync-app-8685c/analytics

---

**Last Updated:** March 11, 2026  
**Version:** 0.13.1+147  
**Status:** ✅ Production Ready
