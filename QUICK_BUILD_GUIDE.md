# 🚀 FlowGroove - Complete Build & Deployment Guide

**Quick reference for deploying to all platforms**

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Build Commands](#build-commands)
3. [Deployment Options](#deployment-options)
4. [FTP Setup](#ftp-setup)
5. [GitHub Pages](#github-pages)
6. [APK Release](#apk-release)
7. [Troubleshooting](#troubleshooting)

---

## 🎯 Quick Start

### **Option 1: Full Release (Recommended)**

Builds and deploys **everywhere** in one command:

```bash
make release-stable
```

**What it does:**
1. ✅ Increments build number
2. ✅ Builds Web + Android APK + AAB
3. ✅ Deploys to FTP (flowgroove.app)
4. ✅ Deploys to GitHub Pages
5. ✅ Deploys to Firebase Hosting
6. ✅ Creates Git tag and commit
7. ✅ Pushes to GitHub

**Time:** ~5-10 minutes

---

### **Option 2: Quick Deploy (Existing Build)**

If you already have a build and just want to deploy:

```bash
make deploy-flowgroove
```

**What it does:**
1. ✅ Deploys `build/web/` to FTP (flowgroove.app)
2. ✅ No build step (faster)

**Time:** ~1-2 minutes

---

## 🔨 Build Commands

### Build Web Only
```bash
# Simple build
flutter build web

# With Makefile
make build-web
```

**Output:** `build/web/`

---

### Build Android APK
```bash
# Release APK (for distribution)
flutter build apk --release

# With Makefile
make build-android
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

---

### Build Android AAB (Play Store)
```bash
flutter build appbundle --release
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

---

### Build All Platforms
```bash
make build-all
```

---

## 🌐 Deployment Options

### 1. FTP Deployment (flowgroove.app)

**Deploy to production website:**

```bash
# Build + Deploy
make deploy-stable

# Or deploy existing build
make deploy-flowgroove
```

**FTP Details:**
- **Host:** `ftp.soundingdoubts.pt` (or `194.39.124.68`)
- **Username:** `sounding`
- **Password:** `M*9!atF0g43QJv`
- **Remote Dir:** `flowgroove.app`
- **URL:** https://flowgroove.app/

**Manual FTP Upload:**
```bash
# Using lftp (faster)
lftp -c "
  set ftp:ssl-allow no
  open -u 'sounding','M*9!atF0g43QJv' ftp.soundingdoubts.pt
  cd flowgroove.app
  mirror --reverse --delete build/web .
  bye
"

# Using curl (slower, built-in)
./scripts/deploy-to-flowgroove.sh
```

---

### 2. GitHub Pages Deployment

**Deploy to GitHub Pages backup:**

```bash
# Build + Deploy
make deploy

# Or use script
./scripts/deploy-all.sh --skip-ftp --skip-firebase
```

**URL:** https://berlogabob.github.io/flutter-FlowGroove-app/

**Manual Deploy:**
```bash
flutter build web
npx gh-pages -d build/web -b gh-pages -m "Deploy $(grep '^version:' pubspec.yaml)"
```

---

### 3. Firebase Hosting

**Deploy to Firebase:**

```bash
# Build + Deploy
make deploy-firebase

# Or manual
flutter build web
firebase deploy --only hosting --project repsync-app-8685c
```

**URL:** https://repsync-app-8685c.web.app/

---

### 4. Multi-Platform Deploy Script

**Deploy to ALL platforms at once:**

```bash
# Full deployment
./scripts/deploy-all.sh

# Skip Android (faster)
./scripts/deploy-all.sh --skip-android

# Skip FTP only
./scripts/deploy-all.sh --skip-ftp

# Skip GitHub only
./scripts/deploy-all.sh --skip-github

# Skip Firebase only
./scripts/deploy-all.sh --skip-firebase
```

---

## 📦 FTP Setup

### Install lftp (Recommended for Faster Uploads)

```bash
# macOS
brew install lftp

# Ubuntu/Debian
sudo apt-get install lftp

# Fedora
sudo dnf install lftp
```

**Without lftp:** Uses curl (slower but works)

---

### FTP Credentials

Already configured in scripts from `FTP_data.md`:

```env
FTP Host: ftp.soundingdoubts.pt (or 194.39.124.68)
FTP User: sounding
FTP Pass: M*9!atF0g43QJv
Remote Dir: flowgroove.app
```

**Test FTP Connection:**
```bash
lftp -u sounding,'M*9!atF0g43QJv' ftp.soundingdoubts.pt -e "ls; quit"
```

---

## 📱 GitHub Pages

### Deploy to GitHub Pages

```bash
# Method 1: Using Makefile
make deploy-github

# Method 2: Using script
./scripts/deploy-all.sh --skip-ftp --skip-firebase --skip-android

# Method 3: Manual
flutter build web
npx gh-pages -d build/web -b gh-pages
```

**URL:** https://berlogabob.github.io/flutter-FlowGroove-app/

---

### GitHub Pages Setup (One-Time)

```bash
# Create gh-pages branch if it doesn't exist
git checkout --orphan gh-pages
git reset --hard
git commit --allow-empty -m "Initial commit"
git push origin gh-pages
git checkout main
```

---

## 📲 APK Release

### Build Release APK

```bash
# Build release APK
flutter build apk --release

# Build split APKs (smaller, per architecture)
flutter build apk --split-per-abi

# Build AAB for Play Store
flutter build appbundle --release
```

**Output Locations:**
- **APK:** `build/app/outputs/flutter-apk/app-release.apk`
- **Split APKs:** `build/app/outputs/flutter-apk/`
- **AAB:** `build/app/outputs/bundle/release/app-release.aab`

---

### Create GitHub Release with APK

```bash
# Using Makefile (automated)
make release-stable

# Manual
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //')
gh release create "v$VERSION" \
  build/app/outputs/flutter-apk/app-release.apk \
  --title "Release $VERSION" \
  --notes "Release notes here"
```

---

### Share APK with Testers

```bash
# After building APK
make deploy-stable
```

APK will be included in GitHub Release automatically!

**Testers can download from:**
https://github.com/berlogabob/flutter-FlowGroove-app/releases

---

## 🛠️ Makefile Commands Reference

### Deployment
```bash
make deploy              # Deploy to ALL platforms
make deploy-stable       # Same as 'make deploy'
make deploy-web          # Web only (FTP + GitHub + Firebase)
make deploy-ftp          # FTP only
make deploy-github       # GitHub Pages only
make deploy-firebase     # Firebase only
make deploy-flowgroove   # FTP only (existing build)
```

### Build
```bash
make build-web           # Build web
make build-android       # Build Android APK
make build-all           # Build all platforms
```

### Development
```bash
make dev                 # Run in Chrome
make dev-web             # Run web with HTML renderer
make clean               # Clean build artifacts
make test                # Run tests
make analyze             # Run flutter analyze
```

### Version
```bash
make version             # Show current version
make bump                # Increment build number
```

---

## 🔄 Typical Workflows

### Workflow 1: Quick Hotfix

```bash
# 1. Make changes
git add .
git commit -m "Fix: urgent bug fix"

# 2. Deploy immediately
make deploy-flowgroove
```

**Time:** ~2 minutes

---

### Workflow 2: Regular Release

```bash
# 1. Make changes
git add .
git commit -m "Feature: new amazing feature"

# 2. Build and deploy everywhere
make release-stable
```

**Time:** ~5-10 minutes

---

### Workflow 3: Test Before Production

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

**Time:** ~10-15 minutes total

---

### Workflow 4: Android Release Only

```bash
# 1. Build APK
make build-android

# 2. Build AAB for Play Store
flutter build appbundle --release

# 3. Create GitHub Release
make release-stable
```

**Time:** ~5-8 minutes

---

## 📊 Deployment Checklist

### Before Deploying

- [ ] Code committed to git
- [ ] Tests passing (`make test`)
- [ ] No analyzer errors (`make analyze`)
- [ ] Tested locally (`flutter run -d chrome`)
- [ ] Version number correct (`make version`)

### After Deploying

- [ ] Test https://flowgroove.app/
- [ ] Check login works
- [ ] Test main features
- [ ] Check browser console for errors
- [ ] Verify version in profile screen
- [ ] Test on mobile devices
- [ ] Monitor Firebase Analytics

---

## 🔍 Troubleshooting

### FTP Upload Fails

**Error:** `Connection timeout`

**Solutions:**
```bash
# 1. Test connection
lftp -u sounding,'M*9!atF0g43QJv' ftp.soundingdoubts.pt -e "ls; quit"

# 2. Try IP address instead
export FTP_HOST=194.39.124.68
make deploy-flowgroove

# 3. Check if server is reachable
ping ftp.soundingdoubts.pt
```

---

### Slow FTP Upload

**Solution:** Install lftp
```bash
brew install lftp
```

---

### White Screen After Deploy

**Solutions:**
```bash
# 1. Clear browser cache (hard refresh)
Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)

# 2. Check base-href
curl -s https://flowgroove.app/ | grep "base href"
# Should show: <base href="/" />

# 3. Rebuild and redeploy
flutter clean
make build-web
make deploy-flowgroove
```

---

### Version Not Updating

```bash
# 1. Clean and rebuild
flutter clean
make build-web

# 2. Check version.json
cat build/web/version.json

# 3. Redeploy
make deploy-flowgroove
```

---

### Firebase Auth Error

**Error:** `auth/unauthorized-domain`

**Solution:**
1. Go to: https://console.firebase.google.com/project/repsync-app-8685c/authentication/providers
2. Click "Sign-in method" tab
3. Add domain to "Authorized domains"
4. Add: `flowgroove.app` and `www.flowgroove.app`

✅ Already configured!

---

## 📞 Quick Reference

### URLs
- **Production:** https://flowgroove.app/
- **GitHub Pages:** https://berlogabob.github.io/flutter-FlowGroove-app/
- **Firebase:** https://repsync-app-8685c.web.app/
- **GitHub Repo:** https://github.com/berlogabob/flutter-FlowGroove-app

### Firebase Console
- **Project:** https://console.firebase.google.com/project/repsync-app-8685c
- **Auth:** https://console.firebase.google.com/project/repsync-app-8685c/authentication
- **Hosting:** https://console.firebase.google.com/project/repsync-app-8685c/hosting
- **Analytics:** https://console.firebase.google.com/project/repsync-app-8685c/analytics

### FTP
- **Host:** ftp.soundingdoubts.pt (194.39.124.68)
- **User:** sounding
- **Pass:** M*9!atF0g43QJv
- **Dir:** flowgroove.app

---

## 🎯 Most Common Commands

```bash
# Full release (use this most of the time)
make release-stable

# Quick deploy (already have build)
make deploy-flowgroove

# Build and test locally
flutter build web && flutter run -d chrome

# Check version
make version

# Clean everything
make clean
```

---

**Last Updated:** March 14, 2026  
**Version:** 0.13.1+167  
**Status:** ✅ Production Ready
