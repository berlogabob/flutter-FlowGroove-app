# 🎨 FlowGroove Icon Generation Guide

**Logo Source:** `assets/logo_bckgrnd.png`  
**Date:** March 11, 2026

---

## ⚠️ Current Issue

The logo file has macOS security restrictions that prevent automated icon generation. This is a common issue with files downloaded from the internet or synced via iCloud.

---

## 🔧 Solution: Manual Icon Generation

### Option 1: Using flutter_launcher_icons (Recommended)

#### Step 1: Install Package
```bash
flutter pub add dev:flutter_launcher_icons
```

#### Step 2: Configuration Already Created
File: `flutter_launcher_icons.yaml`

```yaml
name: flutter_launcher_icons
description: "FlowGroove Launcher Icons"

flutter_launcher_icons:
  # Android
  android: true
  image_path: "assets/logo_bckgrnd.png"
  adaptive_icon_background: "#1A1A2E"
  adaptive_icon_foreground: "assets/logo_bckgrnd.png"
  
  # iOS
  ios: true
  image_path_ios: "assets/logo_bckgrnd.png"
  
  # Web
  web:
    generate: true
    image_path: "assets/logo_bckgrnd.png"
```

#### Step 3: Fix File Permissions
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine assets/logo_bckgrnd.png

# Or copy to a new file
cp assets/logo_bckgrnd.png /tmp/logo_temp.png
cp /tmp/logo_temp.png assets/logo_bckgrnd.png
```

#### Step 4: Generate Icons
```bash
# Run icon generator
dart run flutter_launcher_icons
```

---

### Option 2: Manual Icon Generation (If Option 1 Fails)

#### Required Sizes by Platform

**Android:**
- mdpi: 48x48
- hdpi: 72x72
- xhdpi: 96x96
- xxhdpi: 144x144
- xxxhdpi: 192x192

**Android Adaptive Icons (8.0+):**
- Foreground: 108x108 (safe zone)
- Background: 108x108

**iOS:**
- iPhone:
  - 20x20 (@2x, @3x)
  - 29x29 (@2x, @3x)
  - 40x40 (@2x, @3x)
  - 60x60 (@2x, @3x)
- iPad:
  - 20x20 (@1x, @2x)
  - 29x29 (@1x, @2x)
  - 40x40 (@1x, @2x)
  - 76x76 (@1x, @2x)
  - 83.5x83.5 (@2x)
- App Store: 1024x1024

**Web:**
- Favicon: 16x16, 32x32
- PWA Icon: 192x192, 512x512
- Touch Icon: 96x96

---

### Option 3: Online Icon Generator

1. **Go to:** https://appicon.co/
2. **Upload:** `assets/logo_bckgrnd.png`
3. **Select platforms:** Android, iOS, Web
4. **Download** generated icons
5. **Extract** to appropriate directories

---

## 📁 Icon Placement

### Android Icons
```
android/app/src/main/res/
├── mipmap-mdpi/ic_launcher.png (48x48)
├── mipmap-hdpi/ic_launcher.png (72x72)
├── mipmap-xhdpi/ic_launcher.png (96x96)
├── mipmap-xxhdpi/ic_launcher.png (144x144)
├── mipmap-xxxhdpi/ic_launcher.png (192x192)
└── mipmap-anydpi-v26/
    ├── ic_launcher.xml
    ├── ic_launcher_foreground.png (108x108)
    └── ic_launcher_background.png (108x108)
```

### iOS Icons
```
ios/Runner/Assets.xcassets/AppIcon.appiconset/
├── Contents.json
├── icon-20x20.png
├── icon-29x29.png
├── icon-40x40.png
├── icon-58x58.png
├── icon-60x60.png
├── icon-76x76.png
├── icon-80x80.png
├── icon-87x87.png
├── icon-120x120.png
├── icon-152x152.png
├── icon-167x167.png
├── icon-180x180.png
└── icon-1024x1024.png
```

### Web Icons
```
web/icons/
├── favicon-16x16.png
├── favicon-32x32.png
├── icon-192x192.png
└── icon-512x512.png
```

---

## 🎨 Color Scheme

**Background Color:** `#1A1A2E` (Dark Blue)

This color is used for:
- Android adaptive icon background
- Web manifest background
- iOS app icon background (if needed)

---

## ✅ Verification Checklist

After generating icons:

### Android
- [ ] All 5 density icons exist
- [ ] Adaptive icon XML created
- [ ] Colors.xml created with background color
- [ ] AndroidManifest.xml references icons

### iOS
- [ ] All icon sizes generated
- [ ] Contents.json valid
- [ ] Info.plist references AppIcon

### Web
- [ ] 192x192 and 512x512 icons exist
- [ ] Favicons generated
- [ ] manifest.json updated
- [ ] index.html references icons

---

## 🛠️ Scripts Created

### 1. `scripts/generate-icons.sh` (Bash)
Uses macOS `sips` command for image processing.

**Usage:**
```bash
./scripts/generate-icons.sh
```

### 2. `scripts/generate-icons.py` (Python)
Uses Pillow library for cross-platform support.

**Usage:**
```bash
python3 scripts/generate-icons.py
```

**Requirements:**
```bash
pip3 install Pillow
```

---

## 🔍 Troubleshooting

### Issue: "Operation not permitted"

**Cause:** macOS security restrictions

**Solutions:**

1. **Remove quarantine:**
   ```bash
   xattr -d com.apple.quarantine assets/logo_bckgrnd.png
   ```

2. **Copy to new file:**
   ```bash
   cp assets/logo_bckgrnd.png /tmp/logo.png
   cp /tmp/logo.png assets/logo_bckgrnd.png
   ```

3. **Use Preview app:**
   - Open logo in Preview
   - File → Export
   - Save as new PNG
   - Use new file

### Issue: Icons not showing

**Android:**
```bash
flutter clean
flutter pub get
flutter run
```

**iOS:**
```bash
cd ios
pod install
cd ..
flutter clean
flutter run
```

**Web:**
```bash
flutter clean
flutter build web
```

---

## 📊 Quick Reference

### Generate All Icons
```bash
# Using flutter_launcher_icons
dart run flutter_launcher_icons

# Using script
python3 scripts/generate-icons.py
```

### Test on Platforms
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome
```

### Clean and Rebuild
```bash
flutter clean
flutter pub get
flutter build apk  # or web/ios
```

---

## 🎯 Next Steps

1. **Fix file permissions** on logo
2. **Install flutter_launcher_icons**
3. **Run icon generator**
4. **Test on all platforms**
5. **Commit icons to git**

---

## 📞 Resources

- **flutter_launcher_icons:** https://pub.dev/packages/flutter_launcher_icons
- **Android Icons:** https://developer.android.com/guide/practices/ui_guidelines/icon_design_launcher
- **iOS Icons:** https://developer.apple.com/design/human-interface-guidelines/app-icons
- **Web Icons:** https://web.dev/add-manifest/

---

**Status:** ⚠️ Permission issue detected  
**Solution:** Use flutter_launcher_icons package or fix permissions  
**Priority:** High (needed for production)
