# RepSync - Deployment Checklist

**Last Updated:** February 19, 2026
**Version:** 1.0.0

---

## Table of Contents

1. [Web Deployment (GitHub Pages)](#web-deployment-github-pages)
2. [Web Deployment (Firebase Hosting)](#web-deployment-firebase-hosting)
3. [Android Deployment](#android-deployment)
4. [iOS Deployment](#ios-deployment)
5. [Desktop Deployment](#desktop-deployment)
6. [Post-Deployment Verification](#post-deployment-verification)

---

## Web Deployment (GitHub Pages)

### Pre-Deployment Checklist

- [ ] **Update version in `pubspec.yaml`**
  ```yaml
  version: 1.0.1+2  # major.minor.patch+build
  ```

- [ ] **Run Flutter analysis**
  ```bash
  flutter analyze
  ```
  - [ ] All errors fixed
  - [ ] All warnings addressed

- [ ] **Run tests**
  ```bash
  flutter test
  ```
  - [ ] All tests pass

- [ ] **Update `web/config.js` with production credentials**
  ```javascript
  window.env = {
    "SPOTIFY_CLIENT_ID": "your_production_client_id",
    "SPOTIFY_CLIENT_SECRET": "your_production_client_secret"
  };
  ```

- [ ] **Verify `.gitignore` excludes sensitive files**
  - [ ] `.env` is gitignored
  - [ ] `web/config.js` is gitignored (use template)

### Build & Deploy

- [ ] **Clean previous builds**
  ```bash
  flutter clean
  rm -rf docs/*
  ```

- [ ] **Build for web with correct base-href**
  ```bash
  flutter build web --release --base-href "/flutter-repsync-app/"
  ```

- [ ] **Copy build to docs folder**
  ```bash
  cp -r build/web/* docs/
  ```

- [ ] **Create deployment files**
  ```bash
  touch docs/.nojekyll
  cp docs/index.html docs/404.html
  ```

- [ ] **Commit and push to GitHub**
  ```bash
  git add docs/
  git commit -m "Deploy: update GitHub Pages [version]"
  git push
  ```

### Post-Deployment Verification

- [ ] **Access the application**
  - [ ] URL: `https://berlogabob.github.io/flutter-repsync-app/`
  - [ ] Page loads without errors

- [ ] **Test core features**
  - [ ] Login/Registration works
  - [ ] Create band works
  - [ ] Join band with invite code works
  - [ ] Add song works
  - [ ] Spotify BPM fetching works
  - [ ] Search functionality works
  - [ ] PDF export works

- [ ] **Test on different browsers**
  - [ ] Chrome (latest)
  - [ ] Firefox (latest)
  - [ ] Safari (latest)
  - [ ] Edge (latest)

- [ ] **Test on mobile browsers**
  - [ ] iPhone Safari
  - [ ] Android Chrome

- [ ] **Check browser console**
  - [ ] No JavaScript errors
  - [ ] No 404 errors for assets
  - [ ] Environment variables loaded correctly

- [ ] **Verify service worker**
  - [ ] App works offline (after initial load)
  - [ ] Cache updates on new deployment

### GitHub Pages Settings

- [ ] **Repository Settings → Pages**
  - [ ] Source: Deploy from branch
  - [ ] Branch: `main` (or `master`)
  - [ ] Folder: `/docs`
  - [ ] Save settings

- [ ] **Custom Domain (optional)**
  - [ ] Add CNAME file to docs/
  - [ ] Configure DNS records
  - [ ] Enable HTTPS

---

## Web Deployment (Firebase Hosting)

### Pre-Deployment Checklist

- [ ] **Firebase project configured**
  - [ ] Project ID: `repsync-app-8685c`
  - [ ] Hosting enabled

- [ ] **Firebase CLI installed**
  ```bash
  npm install -g firebase-tools
  firebase --version
  ```

- [ ] **Logged in to Firebase**
  ```bash
  firebase login
  ```

- [ ] **Firestore rules deployed**
  ```bash
  firebase deploy --only firestore:rules
  ```

### Build & Deploy

- [ ] **Clean previous builds**
  ```bash
  flutter clean
  ```

- [ ] **Build for web**
  ```bash
  flutter build web --release
  ```

- [ ] **Deploy to Firebase Hosting**
  ```bash
  firebase deploy --only hosting
  ```

### Post-Deployment Verification

- [ ] **Access the application**
  - [ ] URL: `https://repsync-app-8685c.web.app`
  - [ ] Page loads without errors

- [ ] **Test all core features** (same as GitHub Pages checklist)

- [ ] **Custom Domain (optional)**
  - [ ] Add domain in Firebase Console
  - [ ] Update DNS records
  - [ ] SSL certificate provisioned

---

## Android Deployment

### Pre-Deployment Checklist

- [ ] **Update version in `pubspec.yaml`**
  ```yaml
  version: 1.0.1+2
  ```

- [ ] **Update Android version info**
  - [ ] `android/app/build.gradle` versionCode
  - [ ] `android/app/build.gradle` versionName

- [ ] **Configure app signing**
  - [ ] Keystore created
  - [ ] `key.properties` configured
  - [ ] `android/app/build.gradle` signing config

- [ ] **Update app metadata**
  - [ ] App name in `android/app/src/main/AndroidManifest.xml`
  - [ ] App icon replaced
  - [ ] Splash screen configured

- [ ] **Configure Firebase**
  - [ ] `google-services.json` in `android/app/`
  - [ ] Firebase project linked

- [ ] **Update permissions**
  - [ ] Internet permission (default)
  - [ ] Any additional permissions needed

### Build APK (Direct Distribution)

- [ ] **Build release APK**
  ```bash
  flutter build apk --release
  ```

- [ ] **Verify APK created**
  - [ ] Location: `build/app/outputs/flutter-apk/app-release.apk`
  - [ ] File size is reasonable (< 50MB)

- [ ] **Test APK on device**
  - [ ] Install APK on test device
  - [ ] App launches successfully
  - [ ] All features work
  - [ ] No crashes

### Build App Bundle (Play Store)

- [ ] **Build release App Bundle**
  ```bash
  flutter build appbundle --release
  ```

- [ ] **Verify AAB created**
  - [ ] Location: `build/app/outputs/bundle/release/app-release.aab`

- [ ] **Test with Play Internal Testing**
  - [ ] Upload to Google Play Console
  - [ ] Add internal testers
  - [ ] Testers install and verify

### Play Store Deployment (Optional)

- [ ] **Google Play Console Setup**
  - [ ] Developer account created ($25 fee)
  - [ ] App created in Console
  - [ ] Store listing completed

- [ ] **Upload App Bundle**
  - [ ] Go to Production or Internal Testing
  - [ ] Create new release
  - [ ] Upload `app-release.aab`
  - [ ] Fill in release notes

- [ ] **Complete Store Listing**
  - [ ] App title (max 30 chars)
  - [ ] Short description (max 80 chars)
  - [ ] Full description
  - [ ] App icon (512x512)
  - [ ] Feature graphic (1024x500)
  - [ ] Screenshots (phone, tablet)
  - [ ] Privacy policy URL
  - [ ] Content rating questionnaire

- [ ] **Submit for Review**
  - [ ] All required fields completed
  - [ ] Pricing & distribution set
  - [ ] Submit for review

### Post-Deployment Verification

- [ ] **Test on multiple devices**
  - [ ] Different Android versions (10, 11, 12, 13, 14)
  - [ ] Different screen sizes
  - [ ] Different manufacturers (Samsung, Pixel, etc.)

- [ ] **Verify Play Store listing** (if published)
  - [ ] App appears in search
  - [ ] Store listing displays correctly
  - [ ] Download/install works

---

## iOS Deployment

### Pre-Deployment Checklist

- [ ] **Apple Developer Account**
  - [ ] Account active ($99/year)
  - [ ] Team configured

- [ ] **Update version in `pubspec.yaml`**
  ```yaml
  version: 1.0.1+2
  ```

- [ ] **Configure signing in Xcode**
  - [ ] Open `ios/Runner.xcworkspace`
  - [ ] Select Runner project
  - [ ] Signing & Capabilities tab
  - [ ] Team selected
  - [ ] Bundle Identifier unique

- [ ] **Update iOS metadata**
  - [ ] App name in `ios/Runner/Info.plist`
  - [ ] App icon replaced (Assets.xcassets)
  - [ ] Launch screen configured

- [ ] **Configure Firebase**
  - [ ] `GoogleService-Info.plist` in `ios/Runner/`
  - [ ] Firebase project linked

- [ ] **Update Info.plist permissions**
  - [ ] Camera usage description (if needed)
  - [ ] Photo library usage description (if needed)
  - [ ] Any other required permissions

### Build for Testing

- [ ] **Build for simulator**
  ```bash
  flutter build ios --simulator --no-codesign
  ```

- [ ] **Test in simulator**
  - [ ] App launches
  - [ ] All features work

- [ ] **Build for device**
  ```bash
  flutter build ios --release
  ```

### Test on Device

- [ ] **Connect device**
  - [ ] USB cable connected
  - [ ] Device trusted

- [ ] **Run on device**
  ```bash
  flutter run --release
  ```

- [ ] **Verify functionality**
  - [ ] All features work on device
  - [ ] No crashes
  - [ ] Performance acceptable

### App Store Deployment

- [ ] **Archive in Xcode**
  - [ ] Open `ios/Runner.xcworkspace`
  - [ ] Select "Any iOS Device"
  - [ ] Product → Archive
  - [ ] Wait for archive to complete

- [ ] **Upload to App Store Connect**
  - [ ] Distribute App
  - [ ] App Store Connect
  - [ ] Upload

- [ ] **App Store Connect Configuration**
  - [ ] App created in App Store Connect
  - [ ] Bundle ID registered
  - [ ] App information completed:
    - [ ] App name (max 30 chars)
    - [ ] Subtitle (max 30 chars)
    - [ ] Description
    - [ ] Keywords
    - [ ] Support URL
    - [ ] Marketing URL (optional)
    - [ ] Privacy policy URL
    - [ ] Copyright
    - [ ] Contact email

- [ ] **Upload Assets**
  - [ ] App icon (1024x1024)
  - [ ] Screenshots for all required sizes:
    - [ ] 6.7" (1284x2778)
    - [ ] 6.5" (1242x2688)
    - [ ] 5.5" (1242x2208)
    - [ ] iPad Pro (2048x2732)

- [ ] **App Review Information**
  - [ ] Demo account credentials (if required)
  - [ ] Contact information
  - [ ] Notes for reviewer

- [ ] **Submit for Review**
  - [ ] Select build
  - [ ] Answer export compliance questions
  - [ ] Submit for review

### Post-Deployment Verification

- [ ] **TestFlight Testing** (recommended before release)
  - [ ] Build available in TestFlight
  - [ ] Internal testers added
  - [ ] External testers added (if needed)
  - [ ] Feedback collected

- [ ] **App Store Verification** (after approval)
  - [ ] App appears in App Store
  - [ ] Download/install works
  - [ ] All features work in production

---

## Desktop Deployment

### Linux

- [ ] **Build release**
  ```bash
  flutter build linux --release
  ```

- [ ] **Package for distribution**
  - [ ] Create .deb package (Debian/Ubuntu)
  - [ ] Create .rpm package (Fedora/RHEL)
  - [ ] Or distribute as tarball

- [ ] **Test on target distributions**
  - [ ] Ubuntu 20.04+
  - [ ] Fedora 35+
  - [ ] Other target distros

### macOS

- [ ] **Build release**
  ```bash
  flutter build macos --release
  ```

- [ ] **Code signing** (for distribution outside Mac App Store)
  - [ ] Developer ID certificate
  - [ ] Sign the app
  - [ ] Notarize with Apple

- [ ] **Create DMG** (optional)
  - [ ] Use create-dmg or similar tool

- [ ] **Mac App Store** (optional)
  - [ ] Sandbox entitlements
  - [ ] Submit via App Store Connect

### Windows

- [ ] **Build release**
  ```bash
  flutter build windows --release
  ```

- [ ] **Code signing** (recommended)
  - [ ] Obtain code signing certificate
  - [ ] Sign the executable

- [ ] **Create installer** (optional)
  - [ ] Use Inno Setup, NSIS, or similar
  - [ ] Create MSIX package for Microsoft Store

- [ ] **Test on Windows versions**
  - [ ] Windows 10
  - [ ] Windows 11

---

## Post-Deployment Verification (All Platforms)

### Core Functionality

- [ ] **Authentication**
  - [ ] Login works
  - [ ] Registration works
  - [ ] Logout works
  - [ ] Password reset works (if implemented)

- [ ] **Band Management**
  - [ ] Create band works
  - [ ] Join band with invite code works
  - [ ] Leave band works
  - [ ] Regenerate invite code works
  - [ ] Band members list displays correctly

- [ ] **Song Management**
  - [ ] Add song works
  - [ ] Edit song works
  - [ ] Delete song works
  - [ ] Search songs works
  - [ ] Spotify BPM fetching works
  - [ ] Song list displays correctly

- [ ] **Setlist Management**
  - [ ] Create setlist works
  - [ ] Add songs to setlist works
  - [ ] Reorder setlist works
  - [ ] Export to PDF works

### Data Synchronization

- [ ] **Real-time updates**
  - [ ] Changes sync across devices
  - [ ] Band member changes visible
  - [ ] Song additions visible to all members

- [ ] **Offline support**
  - [ ] App works without internet (cached data)
  - [ ] Changes sync when back online

### Performance

- [ ] **Load times acceptable**
  - [ ] Initial load < 3 seconds
  - [ ] Screen transitions smooth
  - [ ] Search results appear quickly

- [ ] **No memory leaks**
  - [ ] App doesn't crash after extended use
  - [ ] Memory usage stable

### Error Handling

- [ ] **Network errors handled gracefully**
  - [ ] User-friendly error messages
  - [ ] Retry functionality
  - [ ] No app crashes

- [ ] **Invalid input handled**
  - [ ] Form validation works
  - [ ] Clear error messages

---

## Rollback Procedures

### Web (GitHub Pages)

```bash
# Revert to previous commit
git revert HEAD
git push

# Or checkout specific previous version
git checkout <previous-commit>
# Rebuild and deploy
```

### Web (Firebase Hosting)

```bash
# List previous releases
firebase hosting:releases:list

# Rollback to specific version
firebase hosting:rollback
```

### Android (Play Store)

1. Go to Google Play Console
2. Select app
3. Production → Releases
4. Manage release
5. Rollback to previous version

### iOS (App Store)

1. Go to App Store Connect
2. Select app
3. Activity → All Versions
4. Previous version metadata
5. Upload previous build as new version

---

## Deployment Status Tracker

| Platform | Version | Date | Status | Notes |
|----------|---------|------|--------|-------|
| Web (GitHub Pages) | 1.0.0 | - | ⏳ Pending | |
| Web (Firebase) | 1.0.0 | - | ⏳ Pending | |
| Android APK | 1.0.0 | - | ⏳ Pending | |
| Android Play Store | 1.0.0 | - | ⏳ Pending | |
| iOS App Store | 1.0.0 | - | ⏳ Pending | |
| Linux Desktop | 1.0.0 | - | ⏳ Pending | |
| macOS Desktop | 1.0.0 | - | ⏳ Pending | |
| Windows Desktop | 1.0.0 | - | ⏳ Pending | |

---

## Resources

- [Flutter Deployment Guide](https://docs.flutter.dev/deployment)
- [GitHub Pages Documentation](https://pages.github.com/)
- [Firebase Hosting](https://firebase.google.com/docs/hosting)
- [Google Play Console](https://play.google.com/console)
- [App Store Connect](https://appstoreconnect.apple.com/)

---

**Checklist Version:** 1.0
**Last Updated:** February 19, 2026
