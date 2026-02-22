# Release Notes - RepSync v0.10.1+1

**Release Date:** February 22, 2026

## Overview

This release introduces significant improvements to the RepSync app, focusing on offline-first architecture, mobile audio support, enhanced navigation, and overall code quality improvements.

## What's New

### 🏗️ Offline-First Architecture
- Implemented Hive local storage for offline access to songs and setlists
- Enhanced offline synchronization with Firestore
- Users can now access their repertoire without an internet connection
- Automatic sync when connectivity is restored

### 🎵 Mobile Audio Support
- Integrated audioplayers package for audio playback on mobile devices
- Full audio support for practice and performance scenarios
- Platform-specific audio engine implementations (mobile and web)

### 🧭 Enhanced Navigation
- Implemented go_router for declarative routing
- Better navigation management throughout the app
- Improved deep linking support

### 🛡️ Robust Error Handling
- Comprehensive error handling throughout the application
- Better user feedback for error states
- Improved error recovery mechanisms

### ✨ UX Improvements
- Various user experience enhancements across the application
- Improved offline indicator widget
- Better visual feedback for user actions

### 🔧 Code Quality Improvements
- Refactored code for better maintainability
- Performance optimizations
- Updated dependencies to latest stable versions

## Build Artifacts

- **Web:** `build/web/` - Ready for deployment to Firebase Hosting or any web server
- **Android:** `build/app/outputs/flutter-apk/app-release.apk` (58.0MB)

## Testing

- ✅ Flutter analyze completed (203 issues, mostly linting suggestions)
- ✅ Flutter test suite executed (693 tests)
- ✅ Web build completed successfully
- ✅ Android APK build completed successfully
- ⏳ Android device testing ready (MrAndroid telemetry)

## Technical Details

### Version Information
- **Version:** 0.10.1+1
- **Flutter:** ^3.10.7
- **Dart:** ^3.10.7

### Key Dependencies Updated
- cloud_firestore: ^6.1.2
- connectivity_plus: ^6.1.3
- firebase_auth: ^6.1.4
- firebase_core: ^4.4.0
- flutter_riverpod: ^3.2.1
- hive: ^2.2.3
- audioplayers: ^6.0.0
- go_router: ^16.2.0

## Installation

### Web Deployment
```bash
# Deploy to Firebase Hosting
firebase deploy --only hosting

# Or copy build/web/ to your web server
```

### Android Installation
```bash
# Install APK on connected device
adb install build/app/outputs/flutter-apk/app-release.apk

# Or distribute via Google Play Console
```

## Known Issues

- Some test files have pre-existing failures unrelated to this release
- Minor linting warnings in production code (print statements, const constructors)

## Upgrade Notes

This is a minor release with no breaking changes. Users can upgrade directly from any previous version.

---

**Built with ❤️ for musicians and cover bands**
