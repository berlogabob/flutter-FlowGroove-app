# APP ICONS GENERATION GUIDE
**Makefile Target: `make icons`**

---

## OVERVIEW

Generate complete set of app icons for Android, iOS, and Web from a single source image.

---

## USAGE

### Basic Command
```bash
make icons SOURCE=path/to/logo.png
```

### Examples

#### macOS (uses sips)
```bash
make icons SOURCE=assets/logo/RepSync_Logo_1024.png
```

#### Linux/Windows (uses ImageMagick)
```bash
make icons SOURCE=assets/logo/RepSync_Logo_1024.png
```

---

## REQUIREMENTS

### Source Image Requirements
- **Format:** PNG (recommended) or JPG
- **Size:** Minimum 1024x1024px (larger is better)
- **Background:** Transparent or solid color
- **Shape:** Square (1:1 aspect ratio)

### System Requirements

#### macOS
- `sips` (built-in) - No installation needed

#### Linux/Windows
- ImageMagick: `sudo apt install imagemagick` (Linux)
- Or download from: https://imagemagick.org/

---

## GENERATED ICONS

### Android Icons

| Density | Size | Location |
|---------|------|----------|
| mdpi | 48x48 | `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` |
| hdpi | 72x72 | `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` |
| xhdpi | 96x96 | `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` |
| xxhdpi | 144x144 | `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` |
| xxxhdpi | 192x192 | `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` |

### iOS Icons

| Size | Location |
|------|----------|
| 20x20 | `ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-20.png` |
| 29x29 | `ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-29.png` |
| 40x40 | `ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-40.png` |
| 60x60 | `ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-60.png` |
| 76x76 | `ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-76.png` |
| 83.5x83.5 | `ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-83.5.png` |
| 1024x1024 | `ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-1024.png` |

### Web Icons

| Size | Location |
|------|----------|
| 192x192 | `web/icons/icon-192.png` |
| 512x512 | `web/icons/icon-512.png` |

---

## STEP-BY-STEP GUIDE

### Step 1: Prepare Source Logo

1. Create/export logo at **1024x1024px** minimum
2. Save as PNG with transparency
3. Place in project folder (e.g., `assets/logo/`)

### Step 2: Generate Icons

```bash
cd /Users/berloga/Documents/GitHub/flutter_repsync_app
make icons SOURCE=assets/logo/RepSync_Logo_1024.png
```

### Step 3: Verify Icons

```bash
# Check Android icons
ls -lh android/app/src/main/res/mipmap-*/ic_launcher.png

# Check iOS icons
ls -lh ios/Runner/Assets.xcassets/AppIcon.appiconset/

# Check web icons
ls -lh web/icons/
```

### Step 4: Update Configuration (if needed)

#### Android
Already configured in `AndroidManifest.xml`:
```xml
android:icon="@mipmap/ic_launcher"
```

#### iOS
Update `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` if needed.

#### Web
Update `web/manifest.json`:
```json
"icons": [
  {
    "src": "icons/icon-192.png",
    "type": "image/png",
    "sizes": "192x192"
  },
  {
    "src": "icons/icon-512.png",
    "type": "image/png",
    "sizes": "512x512"
  }
]
```

### Step 5: Rebuild App

```bash
flutter clean
flutter pub get
flutter build apk --release
```

---

## EXAMPLE OUTPUT

```bash
$ make icons SOURCE=assets/logo/RepSync_Logo_1024.png

🎨 Generating app icons...
📱 Generating Android icons...
🍎 Generating iOS icons...
🌐 Generating web icons...

✅ Icons generated successfully!

📱 Android: android/app/src/main/res/mipmap-*/
🍎 iOS: ios/Runner/Assets.xcassets/AppIcon.appiconset/
🌐 Web: web/icons/

⚠️  Note: You may need to update AndroidManifest.xml and Info.plist to reference new icons
```

---

## TROUBLESHOOTING

### Error: "Source file not found"

**Solution:**
```bash
# Check file exists
ls -lh assets/logo/RepSync_Logo_1024.png

# Use absolute path
make icons SOURCE=/absolute/path/to/logo.png
```

### Error: "sips: command not found" (Linux/Windows)

**Solution:**
```bash
# Install ImageMagick
sudo apt install imagemagick  # Linux
# or download from https://imagemagick.org/
```

### Error: "convert: command not found"

**Solution:**
```bash
# Install ImageMagick
brew install imagemagick  # macOS
sudo apt install imagemagick  # Linux
```

### Icons Look Blurry

**Cause:** Source image too small

**Solution:**
- Use source image at least 1024x1024px
- Preferably 2048x2048px for best quality

### Icons Have White Background

**Cause:** Source image has no transparency

**Solution:**
- Use PNG with transparent background
- Or use solid color that matches your app theme

---

## BEST PRACTICES

### Logo Design
1. **Simple is better** - Details get lost at small sizes
2. **High contrast** - Ensure visibility on all backgrounds
3. **Centered** - Leave padding around edges
4. **Test at small sizes** - Check 48x48px version

### File Organization
```
assets/
└── logo/
    ├── RepSync_Logo_1024.png    # Source for icons
    ├── RepSync_Logo_2048.png    # High-res source
    └── RepSync_Logo_Vector.svg  # Vector version
```

### Version Control
```bash
# Add generated icons to git
git add android/app/src/main/res/mipmap-*/ic_launcher.png
git add ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png
git add web/icons/*.png

# Or ignore if you regenerate often (add to .gitignore)
# android/**/ic_launcher.png
# ios/**/icon-*.png
# web/icons/*.png
```

---

## ALTERNATIVE TOOLS

### Flutter Launcher Icons (Recommended for Production)

Add to `pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: true
  web:
    generate: true
  image_path: "assets/logo/RepSync_Logo_1024.png"
  min_sdk_android: 21
```

Generate:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

### App Icon Generator (Online)

Website: https://appicon.co/

1. Upload 1024x1024px logo
2. Download all platforms pack
3. Extract to project folders

---

## QUICK REFERENCE

### Command
```bash
make icons SOURCE=path/to/logo.png
```

### Output Locations
- **Android:** `android/app/src/main/res/mipmap-*/`
- **iOS:** `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- **Web:** `web/icons/`

### Required Size
- **Minimum:** 1024x1024px
- **Recommended:** 2048x2048px

### Format
- **Best:** PNG with transparency
- **Acceptable:** JPG with solid background

---

**Last Updated:** 2026-02-24  
**Version:** 0.11.0+2
