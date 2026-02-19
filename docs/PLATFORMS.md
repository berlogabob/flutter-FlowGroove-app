# RepSync - Platform Support Guide

**Last Updated:** February 19, 2026
**Version:** 1.0.0

---

## Table of Contents

1. [Platform Overview](#platform-overview)
2. [Web Platform](#web-platform)
3. [Mobile Platforms](#mobile-platforms)
4. [Desktop Platforms](#desktop-platforms)
5. [Platform Comparison](#platform-comparison)
6. [Feature Availability](#feature-availability)

---

## Platform Overview

RepSync is built with Flutter, enabling deployment to multiple platforms from a single codebase.

### Supported Platforms

| Platform | Status | Priority | Build Command |
|----------|--------|----------|---------------|
| **Web** | ✅ Production Ready | Primary | `flutter build web` |
| **Android** | ✅ Production Ready | High | `flutter build apk` |
| **iOS** | ✅ Production Ready | High | `flutter build ios` |
| **Linux** | ⚠️ Community Support | Low | `flutter build linux` |
| **macOS** | ⚠️ Community Support | Low | `flutter build macos` |
| **Windows** | ⚠️ Community Support | Low | `flutter build windows` |

### Platform Priority

1. **Web (Primary)** - Main target platform, optimized for mobile browsers
2. **Android** - Secondary priority, full feature support
3. **iOS** - Secondary priority, full feature support
4. **Desktop** - Community support, basic functionality

---

## Web Platform

### Overview

The web platform is the **primary target** for RepSync. It's optimized for:

- Mobile browsers (iPhone Safari, Android Chrome)
- Desktop browsers (Chrome, Firefox, Safari, Edge)
- Progressive Web App (PWA) features

### Build Configuration

```bash
# Build for production
flutter build web --release --base-href "/flutter-repsync-app/"

# With specific renderer
flutter build web --release --web-renderer canvaskit
```

### Deployment Options

#### GitHub Pages

**URL:** `https://berlogabob.github.io/flutter-repsync-app/`

**Deployment:**

```bash
make deploy
```

**Configuration:**
- Base href: `/flutter-repsync-app/`
- Output: `docs/` folder
- Auto-deploy on push

#### Firebase Hosting

**URL:** `https://repsync-app-8685c.web.app`

**Deployment:**

```bash
firebase deploy --only hosting
```

**Configuration:**
- Base href: `/`
- Output: `public/` folder
- Global CDN

### Web-Specific Features

#### Environment Variables

Web uses `web/config.js` for environment variables:

```javascript
window.env = {
  "SPOTIFY_CLIENT_ID": "your_client_id",
  "SPOTIFY_CLIENT_SECRET": "your_client_secret"
};
```

#### Service Worker

The web build includes a service worker for:

- Offline support
- Asset caching
- Faster subsequent loads

#### PWA Features

- Add to home screen
- Offline mode
- Push notifications (future)

### Browser Support

| Browser | Version | Support |
|---------|---------|---------|
| Chrome | 90+ | ✅ Full |
| Firefox | 88+ | ✅ Full |
| Safari | 14+ | ✅ Full |
| Edge | 90+ | ✅ Full |
| Samsung Internet | 14+ | ✅ Full |

### Mobile Browser Optimization

The app is optimized for mobile browsers:

- Responsive design
- Touch-friendly UI
- Mobile-first layout
- PWA installable

### Web Limitations

| Feature | Limitation | Workaround |
|---------|------------|------------|
| File System Access | Limited | Use cloud storage |
| Push Notifications | Limited support | Use email notifications |
| Background Sync | Limited | Use service worker |
| Native Features | Not available | Use web APIs |

---

## Mobile Platforms

### Android

#### Overview

Full-featured Android app with native performance.

#### Build Commands

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (Play Store)
flutter build appbundle --release

# Split by ABI
flutter build apk --split-per-abi
```

#### Requirements

- Android 5.0 (API 21) or higher
- ARM64-v8a, armeabi-v7a, x86_64 support

#### Distribution

**Google Play Store:**

```bash
flutter build appbundle --release
```

**Direct APK:**

```bash
flutter build apk --release
```

#### Android-Specific Configuration

**Manifest Permissions:**

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

**Build Configuration:**

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

#### Android Features

- Native navigation
- Material Design UI
- Back button support
- Share intent
- Deep linking (future)

### iOS

#### Overview

Full-featured iOS app with native performance.

#### Build Commands

```bash
# Simulator
flutter build ios --simulator --no-codesign

# Device
flutter build ios --release

# Archive for App Store
# (Done in Xcode)
```

#### Requirements

- iOS 12.0 or higher
- iPhone and iPad support

#### Distribution

**App Store:**

1. Archive in Xcode
2. Upload to App Store Connect
3. Submit for review

**TestFlight:**

1. Upload build
2. Add testers
3. Distribute

#### iOS-Specific Configuration

**Info.plist:**

```xml
<key>MinimumOSVersion</key>
<string>12.0</string>
```

**Capabilities:**

- Push Notifications (future)
- Background Fetch (future)
- Universal Links (future)

#### iOS Features

- Cupertino-style UI
- Native gestures
- Safe area support
- Share sheet
- Deep linking (future)

### Mobile Platform Comparison

| Feature | Android | iOS |
|---------|---------|-----|
| Min Version | 5.0 (API 21) | 12.0 |
| Build Format | APK / AAB | IPA |
| Distribution | Play Store / Direct | App Store |
| Developer Fee | $25 one-time | $99/year |
| Review Time | 1-3 days | 1-3 days |
| Revenue Share | 15-30% | 15-30% |

---

## Desktop Platforms

### Linux

#### Overview

Native Linux desktop application.

#### Build Command

```bash
flutter build linux --release
```

#### Requirements

- GTK 3.14+
- pkg-config
- clang or gcc

#### Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev

# Fedora
sudo dnf install clang cmake ninja-build pkg-config gtk3-devel
```

#### Distribution

- Direct binary
- .deb package (Debian/Ubuntu)
- .rpm package (Fedora/RHEL)
- Snap package
- Flatpak package
- AppImage

### macOS

#### Overview

Native macOS desktop application.

#### Build Command

```bash
flutter build macos --release
```

#### Requirements

- macOS 10.14 (Mojave) or higher
- Xcode command line tools

#### Distribution

- Direct download (DMG)
- Mac App Store
- Homebrew tap

#### Code Signing

Required for distribution outside Mac App Store:

```bash
# Sign the app
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name" \
  build/macos/Build/Products/Release/Runner.app
```

### Windows

#### Overview

Native Windows desktop application.

#### Build Command

```bash
flutter build windows --release
```

#### Requirements

- Windows 10 or higher
- Visual Studio 2022 with C++ workload
- Windows 10 SDK

#### Distribution

- Direct download (ZIP/exe)
- Microsoft Store (MSIX)
- Installer (Inno Setup, NSIS)

#### Code Signing

Recommended for production:

- Obtain code signing certificate
- Sign executable with signtool

### Desktop Platform Comparison

| Feature | Linux | macOS | Windows |
|---------|-------|-------|---------|
| Min Version | Varies | 10.14 | 10 |
| Build Output | Binary | .app | .exe |
| Package Formats | deb, rpm, snap | DMG, pkg | exe, msix |
| Code Signing | Optional | Required | Recommended |

---

## Platform Comparison

### Feature Matrix

| Feature | Web | Android | iOS | Linux | macOS | Windows |
|---------|-----|---------|-----|-------|-------|---------|
| **Core Features** |
| User Authentication | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Band Management | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Song Management | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Setlist Management | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Spotify Integration | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| PDF Export | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Advanced Features** |
| Offline Support | ⚠️ Limited | ✅ | ✅ | ✅ | ✅ | ✅ |
| Push Notifications | ⚠️ Limited | ✅ | ✅ | ⚠️ Limited | ⚠️ Limited | ⚠️ Limited |
| Share Intent | ⚠️ Web Share | ✅ | ✅ | ⚠️ Limited | ✅ | ⚠️ Limited |
| Deep Linking | ✅ | ✅ | ✅ | ⚠️ Limited | ⚠️ Limited | ⚠️ Limited |
| Background Sync | ⚠️ Limited | ✅ | ✅ | ⚠️ Limited | ⚠️ Limited | ⚠️ Limited |

**Legend:**
- ✅ Full support
- ⚠️ Limited support
- ❌ Not available

### Performance Comparison

| Platform | Load Time | Memory Usage | Battery Impact |
|----------|-----------|--------------|----------------|
| Web | Fast | Low | Low |
| Android | Fast | Medium | Medium |
| iOS | Fast | Medium | Medium |
| Linux | Fast | Medium | Medium |
| macOS | Fast | Medium | Medium |
| Windows | Fast | Medium | Medium |

### Development Priority

| Priority | Platform | Reason |
|----------|----------|--------|
| 1 | Web | Primary target, widest reach |
| 2 | Android | Largest mobile market share |
| 3 | iOS | Significant user base |
| 4 | Desktop | Nice-to-have, lower priority |

---

## Feature Availability

### Authentication

| Platform | Method | Notes |
|----------|--------|-------|
| All | Email/Password | Firebase Auth |
| All | Google Sign-In | Future |
| All | Apple Sign-In | iOS required |

### Data Storage

| Platform | Local | Remote | Sync |
|----------|-------|--------|------|
| Web | IndexedDB | Firestore | ✅ Real-time |
| Android | Hive | Firestore | ✅ Real-time |
| iOS | Hive | Firestore | ✅ Real-time |
| Desktop | Hive | Firestore | ✅ Real-time |

### Spotify Integration

| Platform | Support | Notes |
|----------|---------|-------|
| All | ✅ Full | Requires API credentials |

### PDF Export

| Platform | Support | Notes |
|----------|---------|-------|
| All | ✅ Full | Using `pdf` and `printing` packages |

### Offline Support

| Platform | Support | Notes |
|----------|---------|-------|
| Web | ⚠️ Limited | Service worker caching |
| Mobile | ✅ Full | Hive local storage |
| Desktop | ✅ Full | Hive local storage |

---

## Platform-Specific Considerations

### Web

**Pros:**
- No installation required
- Instant updates
- Cross-platform
- Easy sharing (URL)

**Cons:**
- Limited offline support
- No push notifications (limited)
- Browser compatibility issues
- Performance limitations

**Best For:**
- Quick access
- Sharing with band members
- Users who don't want to install apps

### Mobile (Android/iOS)

**Pros:**
- Native performance
- Full offline support
- Push notifications
- Better integration with device

**Cons:**
- Installation required
- App store approval
- Platform-specific builds

**Best For:**
- Regular users
- Offline usage
- Mobile-first experience

### Desktop

**Pros:**
- Large screen experience
- Keyboard/mouse input
- Multi-window support

**Cons:**
- Less common use case
- Platform-specific builds
- Limited mobile features

**Best For:**
- Setlist planning on desktop
- Band administrators
- Power users

---

## Choosing the Right Platform

### For End Users

**Use Web if:**
- You want quick access
- You're on a shared device
- You don't want to install apps

**Use Mobile App if:**
- You use RepSync regularly
- You need offline access
- You want the best experience

**Use Desktop if:**
- You're planning setlists
- You prefer keyboard input
- You're managing multiple bands

### For Developers

**Develop on Web if:**
- You want fastest iteration
- You're testing features
- You don't have mobile devices

**Develop on Mobile if:**
- You're testing mobile-specific features
- You need to test offline support
- You're preparing for release

---

## Resources

- [Flutter Multi-Platform](https://docs.flutter.dev/multi-platform)
- [Web Deployment](https://docs.flutter.dev/deployment/web)
- [Android Deployment](https://docs.flutter.dev/deployment/android)
- [iOS Deployment](https://docs.flutter.dev/deployment/ios)

---

**Platform Guide Version:** 1.0
**Last Updated:** February 19, 2026
