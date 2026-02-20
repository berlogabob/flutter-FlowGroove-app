# RepSync - Comprehensive Build Guide

**Last Updated:** February 19, 2026
**Version:** 1.0.0

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Setup](#project-setup)
3. [Build Commands](#build-commands)
4. [Platform-Specific Builds](#platform-specific-builds)
5. [Troubleshooting](#troubleshooting)
6. [Build Optimization](#build-optimization)

---

## Prerequisites

### Required Software

| Software | Version | Purpose | Installation |
|----------|---------|---------|--------------|
| **Flutter SDK** | 3.19+ (tested on 3.10.7) | Core framework | [flutter.dev](https://flutter.dev) |
| **Dart SDK** | 3.3+ | Programming language | Included with Flutter |
| **Firebase CLI** | Latest | Backend deployment | `npm install -g firebase-tools` |
| **Node.js** | 18+ | Firebase & build tools | [nodejs.org](https://nodejs.org) |
| **Git** | Latest | Version control | [git-scm.com](https://git-scm.com) |

### Platform-Specific Requirements

#### Android
- **Android Studio** Arctic Fox or later
- **Android SDK** (API 21+)
- **Java JDK** 11 or 17

#### iOS
- **macOS** (required for iOS builds)
- **Xcode** 14.0+
- **CocoaPods** (`sudo gem install cocoapods`)

#### Desktop (Linux)
- **GCC** or **Clang**
- **GTK** development libraries
- **pkg-config**

#### Desktop (macOS)
- **Xcode** command line tools

#### Desktop (Windows)
- **Visual Studio 2022** with C++ workload
- **Windows 10 SDK**

---

## Project Setup

### 1. Clone the Repository

```bash
git clone https://github.com/berlogabob/flutter-repsync-app.git
cd flutter-repsync-app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Environment Variables

#### For Local Development

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` with your credentials:

```bash
# Spotify API Credentials
SPOTIFY_CLIENT_ID=your_actual_client_id
SPOTIFY_CLIENT_SECRET=your_actual_client_secret
```

#### For Web Deployment

Edit `web/config.js`:

```javascript
window.env = {
  "SPOTIFY_CLIENT_ID": "your_production_client_id",
  "SPOTIFY_CLIENT_SECRET": "your_production_client_secret"
};
```

### 4. Firebase Setup

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Deploy Firestore rules (required for app functionality)
firebase deploy --only firestore:rules
```

### 5. Verify Setup

```bash
# Run Flutter doctor to check all requirements
flutter doctor

# Run the app in debug mode
flutter run -d chrome
```

---

## Build Commands

### Quick Reference

```bash
# Web (Primary Target)
flutter build web --release --base-href "/flutter-repsync-app/"

# Android
flutter build apk --release           # APK for direct installation
flutter build appbundle --release     # App Bundle for Play Store

# iOS
flutter build ios --release

# Desktop
flutter build linux --release
flutter build macos --release
flutter build windows --release
```

### Detailed Build Commands

#### Web Build (GitHub Pages)

```bash
# Clean build
flutter clean
flutter pub get

# Build with base-href for GitHub Pages
flutter build web --release --base-href "/flutter-repsync-app/"

# Deploy using Makefile
make deploy

# Or manually copy to docs/
cp -r build/web/* docs/
```

#### Android APK Build

```bash
# Debug APK (for testing)
flutter build apk --debug

# Release APK (for distribution)
flutter build apk --release

# Split APKs by ABI (smaller file sizes)
flutter build apk --split-per-abi

# Output location:
# build/app/outputs/flutter-apk/app-release.apk
```

#### Android App Bundle (Play Store)

```bash
flutter build appbundle --release

# Output location:
# build/app/outputs/bundle/release/app-release.aab
```

#### iOS Build

```bash
# Build for simulator (debugging)
flutter build ios --simulator --no-codesign

# Build for device (release)
flutter build ios --release

# Output location:
# build/ios/iphoneos/Runner.app
```

#### Linux Desktop Build

```bash
flutter build linux --release

# Output location:
# build/linux/x64/release/bundle/
```

#### macOS Desktop Build

```bash
flutter build macos --release

# Output location:
# build/macos/Build/Products/Release/Runner.app
```

#### Windows Desktop Build

```bash
flutter build windows --release

# Output location:
# build/windows/runner/Release/
```

---

## Platform-Specific Builds

### Web (Primary Platform)

The RepSync app is optimized for web deployment.

#### Build Configuration

**File:** `web/index.html`

The web build includes:
- CanvasKit renderer for better performance
- Service worker for offline support
- Responsive design for mobile browsers

#### GitHub Pages Deployment

```bash
# Using Makefile (recommended)
make deploy

# Manual deployment
flutter build web --release --base-href "/flutter-repsync-app/"
cp -r build/web/* docs/
git add docs/
git commit -m "Deploy web build"
git push
```

**Access URL:** `https://berlogabob.github.io/flutter-repsync-app/`

#### Firebase Hosting Deployment

```bash
# Build
flutter build web --release

# Deploy to Firebase
firebase deploy --only hosting
```

**Access URL:** `https://repsync-app-8685c.web.app`

#### Web Build Optimization

```bash
# Enable tree shaking
flutter build web --release --tree-shake-icons

# Enable deferred loading (larger initial load, faster subsequent)
flutter build web --release --deferred-components
```

### Android

#### Prerequisites

1. **Create a Keystore** (for signing release builds):

```bash
keytool -genkey -v -keystore ~/rep-sync-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias rep-sync
```

2. **Configure signing** in `android/app/build.gradle`:

```gradle
android {
    ...
    signingConfigs {
        release {
            keyAlias 'rep-sync'
            keyPassword 'YOUR_PASSWORD'
            storeFile file('~/rep-sync-key.jks')
            storePassword 'YOUR_PASSWORD'
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

#### Build APK

```bash
flutter build apk --release
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

#### Build App Bundle (Play Store)

```bash
flutter build appbundle --release
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

#### Test on Device

```bash
# Connect device via USB
# Enable USB debugging on device

# List connected devices
flutter devices

# Run on device
flutter run --release
```

### iOS

#### Prerequisites

1. **Apple Developer Account** (required for device testing and App Store)

2. **Configure Signing** in Xcode:
   - Open `ios/Runner.xcworkspace`
   - Select Runner project
   - Go to "Signing & Capabilities"
   - Select your Team
   - Update Bundle Identifier

3. **Update Info.plist** for required permissions:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access for scanning</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access for images</string>
```

#### Build for Simulator

```bash
flutter build ios --simulator --no-codesign
```

#### Build for Device

```bash
flutter build ios --release
```

#### Archive for App Store

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Any iOS Device (arm64)" as target
3. Product → Archive
4. Distribute App → App Store Connect

### Desktop Platforms

#### Linux

**Dependencies:**

```bash
# Ubuntu/Debian
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev

# Fedora
sudo dnf install clang cmake ninja-build pkg-config gtk3-devel
```

**Build:**

```bash
flutter build linux --release
```

**Run:**

```bash
./build/linux/x64/release/bundle/flutter_repsync_app
```

#### macOS

**Build:**

```bash
flutter build macos --release
```

**Run:**

```bash
./build/macos/Build/Products/Release/Runner.app/Contents/MacOS/Runner
```

#### Windows

**Prerequisites:**

- Visual Studio 2022 with "Desktop development with C++" workload
- Windows 10 SDK

**Build:**

```bash
flutter build windows --release
```

**Run:**

```bash
.\build\windows\runner\Release\flutter_repsync_app.exe
```

---

## Troubleshooting

### Common Build Errors

#### Error: "Flutter SDK not found"

**Solution:**

```bash
# Add Flutter to PATH
export PATH="$PATH:$HOME/flutter/bin"

# Or add to ~/.bashrc or ~/.zshrc
echo 'export PATH="$PATH:$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

#### Error: "No devices found"

**Solution:**

```bash
# For web
flutter devices
flutter run -d chrome

# For Android - enable USB debugging
# For iOS - trust the computer on device

# List all devices
flutter devices
```

#### Error: "Pub get failed"

**Solution:**

```bash
# Clear cache
flutter pub cache clean

# Get dependencies again
flutter pub get

# Or upgrade
flutter pub upgrade
```

#### Error: "Build failed - Gradle issue" (Android)

**Solution:**

```bash
# Clean Gradle cache
cd android
./gradlew clean
cd ..

# Clean Flutter build
flutter clean
flutter pub get

# Rebuild
flutter build apk --release
```

#### Error: "Code signing failed" (iOS)

**Solution:**

1. Open `ios/Runner.xcworkspace` in Xcode
2. Go to Signing & Capabilities
3. Select your Team
4. Ensure Bundle Identifier is unique
5. Try building from Xcode first

#### Error: "Firebase not initialized"

**Solution:**

```bash
# Ensure firebase_options.dart exists
# If not, run:
flutterfire configure

# Or manually copy from another environment
```

#### Error: "Spotify API not configured"

**Solution:**

1. Check `.env` file exists with valid credentials
2. For web, check `web/config.js` exists
3. Restart the app after changing credentials

```bash
flutter clean
flutter run -d chrome
```

### Platform-Specific Issues

#### Web: CanvasKit Not Loading

**Symptoms:** App loads but rendering is slow or broken

**Solution:**

```bash
# Force CanvasKit renderer
flutter build web --release --web-renderer canvaskit
```

#### Android: App Crashes on Launch

**Symptoms:** App installs but crashes immediately

**Solution:**

1. Check `android/app/build.gradle` minSdkVersion (should be 21+)
2. Check Firebase configuration
3. Run `flutter logs` to see crash details

#### iOS: Build Fails with CocoaPods Error

**Symptoms:** "CocoaPods not installed" or pod install fails

**Solution:**

```bash
# Install CocoaPods
sudo gem install cocoapods

# Navigate to iOS folder
cd ios
pod install
cd ..

# Clean and rebuild
flutter clean
flutter build ios
```

#### Desktop: Missing Libraries (Linux)

**Symptoms:** "libgtk-3.so not found"

**Solution:**

```bash
sudo apt-get install libgtk-3-dev
```

### Dependency Problems

#### Conflicting Package Versions

**Solution:**

```bash
# Check for outdated packages
flutter pub outdated

# Upgrade all packages
flutter pub upgrade

# Or upgrade specific package
flutter pub upgrade <package_name>

# If issues persist, check pubspec.lock
git checkout pubspec.lock
flutter pub get
```

#### Build Runner Issues

**Solution:**

```bash
# Clean build
flutter clean

# Run build runner
flutter pub run build_runner build --delete-conflicting-outputs

# Or for watch mode
flutter pub run build_runner watch
```

---

## Build Optimization

### Reduce App Size

#### Web

```bash
# Enable tree shaking
flutter build web --release --tree-shake-icons

# Use CanvasKit (better performance, larger size)
# or HTML renderer (smaller size, slower)
flutter build web --release --web-renderer html
```

#### Android

```bash
# Build split APKs by ABI
flutter build apk --split-per-abi

# Output:
# app-armeabi-v7a-release.apk  (~25MB)
# app-arm64-v8a-release.apk    (~26MB)
# app-x86_64-release.apk       (~27MB)
```

### Improve Build Time

#### Enable Build Caching

```bash
# Flutter automatically caches builds
# Clean only when necessary
flutter clean

# Use incremental builds during development
flutter run
```

#### Parallel Builds

```bash
# Use multiple cores for Gradle
# Add to android/gradle.properties:
org.gradle.parallel=true
org.gradle.daemon=true
org.gradle.jvmargs=-Xmx4096m
```

### Performance Profiling

```bash
# Run with profiling
flutter run --profile

# Open DevTools for analysis
flutter pub global activate devtools
flutter pub global run devtools
```

---

## Build Verification Checklist

### Before Release Build

- [ ] Run `flutter analyze` - fix all errors
- [ ] Run `flutter test` - all tests pass
- [ ] Update version in `pubspec.yaml`
- [ ] Update CHANGELOG
- [ ] Test on target devices
- [ ] Verify Firebase rules deployed
- [ ] Verify environment variables configured

### After Build

- [ ] Verify build artifacts exist
- [ ] Test installation on clean device
- [ ] Verify all features work
- [ ] Check app size is acceptable
- [ ] Verify no console errors

---

## Build Output Locations

| Platform | Command | Output Location |
|----------|---------|-----------------|
| Web | `flutter build web` | `build/web/` |
| Android APK | `flutter build apk` | `build/app/outputs/flutter-apk/` |
| Android Bundle | `flutter build appbundle` | `build/app/outputs/bundle/release/` |
| iOS | `flutter build ios` | `build/ios/iphoneos/` |
| Linux | `flutter build linux` | `build/linux/x64/release/bundle/` |
| macOS | `flutter build macos` | `build/macos/Build/Products/Release/` |
| Windows | `flutter build windows` | `build/windows/runner/Release/` |

---

## Resources

- [Flutter Build Documentation](https://docs.flutter.dev/deployment)
- [Firebase Deployment](https://firebase.google.com/docs/hosting)
- [GitHub Pages Guide](https://pages.github.com/)
- [Play Store Publishing](https://support.google.com/googleplay/android-developer)
- [App Store Publishing](https://developer.apple.com/app-store/)

---

**Build Status:** ✅ Production Ready
**Last Build:** February 19, 2026
**Version:** 1.0.0
