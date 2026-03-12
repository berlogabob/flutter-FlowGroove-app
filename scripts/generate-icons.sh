#!/bin/bash
# Generate complete icon sets for all platforms from logo
# Usage: ./scripts/generate-icons.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOGO="${PROJECT_DIR}/assets/logo_bckgrnd.png"

cd "$PROJECT_DIR"

echo "🎨 FlowGroove Icon Generator"
echo "============================"
echo ""

# Check if logo exists
if [ ! -f "$LOGO" ]; then
    echo "❌ Logo not found: $LOGO"
    echo "Please ensure assets/logo_bckgrnd.png exists"
    exit 1
fi

echo "✅ Logo found: $LOGO"
# Get logo size
WIDTH=$(sips -g pixelWidth "$LOGO" 2>/dev/null | grep pixelWidth | awk '{print $2}')
HEIGHT=$(sips -g pixelHeight "$LOGO" 2>/dev/null | grep pixelHeight | awk '{print $2}')
if [ -n "$WIDTH" ] && [ -n "$HEIGHT" ]; then
    echo "   Size: ${WIDTH}x${HEIGHT} pixels"
else
    echo "   Size: Unable to determine (will use original)"
fi
echo ""

# Check for required tools
if ! command -v sips >/dev/null 2>&1; then
    echo "❌ sips (Scriptable Image Processing System) not found"
    echo "💡 sips is required on macOS for image processing"
    echo "   It should be pre-installed. Try: which sips"
    exit 1
fi

if ! command -v convert >/dev/null 2>&1; then
    echo "⚠️  ImageMagick 'convert' not found"
    echo "💡 Install for better icon generation: brew install imagemagick"
    echo "   Will use sips instead (slower but works)"
fi

echo "📱 Generating icons..."
echo ""

# Create directories
echo "📁 Creating directories..."
mkdir -p android/app/src/main/res/mipmap-mdpi
mkdir -p android/app/src/main/res/mipmap-hdpi
mkdir -p android/app/src/main/res/mipmap-xhdpi
mkdir -p android/app/src/main/res/mipmap-xxhdpi
mkdir -p android/app/src/main/res/mipmap-xxxhdpi
mkdir -p ios/Runner/Assets.xcassets/AppIcon.appiconset
mkdir -p web/icons
mkdir -p assets/app_icons

# Function to resize image using sips
resize_image() {
    local input="$1"
    local output="$2"
    local size="$3"
    sips -z "$size" "$size" "$input" --out "$output" >/dev/null 2>&1
}

# Function to resize with ImageMagick (faster)
resize_image_im() {
    local input="$1"
    local output="$2"
    local size="$3"
    convert "$input" -resize "${size}x${size}" "$output" 2>/dev/null
}

# Choose resize method
if command -v convert >/dev/null 2>&1; then
    RESIZE_CMD="resize_image_im"
else
    RESIZE_CMD="resize_image"
fi

# Generate Android icons
echo "🤖 Generating Android icons..."
ANDROID_SIZES=(48 72 96 144 192)
ANDROID_DENSITIES=("mdpi" "hdpi" "xhdpi" "xxhdpi" "xxxhdpi")

for i in "${!ANDROID_SIZES[@]}"; do
    size=${ANDROID_SIZES[$i]}
    density=${ANDROID_DENSITIES[$i]}
    output="android/app/src/main/res/mipmap-${density}/ic_launcher.png"
    $RESIZE_CMD "$LOGO" "$output" "$size"
    echo "   ✅ ${density}: ${size}x${size}"
done

# Generate adaptive icons (Android 8.0+)
echo ""
echo "📱 Generating Android adaptive icons..."
mkdir -p android/app/src/main/res/mipmap-anydpi-v26

# Create foreground and background for adaptive icons
# For now, we'll use the logo as foreground with a colored background
cat > android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
EOF

# Create foreground (resize logo to fit safe zone)
$RESIZE_CMD "$LOGO" "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_foreground.png" "108"
echo "   ✅ Adaptive icon created (108x108)"

# Create background color
cat > android/app/src/main/res/values/colors.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#1A1A2E</color>
</resources>
EOF
echo "   ✅ Background color created (#1A1A2E)"

# Generate iOS icons
echo ""
echo "🍎 Generating iOS icons..."
IOS_SIZES=(20 29 40 58 60 76 83.5 1024 120 180)

for size in "${IOS_SIZES[@]}"; do
    # Handle fractional sizes
    if [[ "$size" == *"."* ]]; then
        size_int=${size%.*}
    else
        size_int=$size
    fi
    
    output="ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-${size_int}x${size_int}.png"
    $RESIZE_CMD "$LOGO" "$output" "$size_int"
    echo "   ✅ ${size}x${size}"
done

# Create iOS Contents.json
cat > ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json << 'EOF'
{
  "images" : [
    {
      "size" : "20x20",
      "idiom" : "iphone",
      "filename" : "icon-20x20.png",
      "scale" : "2x"
    },
    {
      "size" : "20x20",
      "idiom" : "iphone",
      "filename" : "icon-40x40.png",
      "scale" : "3x"
    },
    {
      "size" : "29x29",
      "idiom" : "iphone",
      "filename" : "icon-58x58.png",
      "scale" : "2x"
    },
    {
      "size" : "29x29",
      "idiom" : "iphone",
      "filename" : "icon-87x87.png",
      "scale" : "3x"
    },
    {
      "size" : "40x40",
      "idiom" : "iphone",
      "filename" : "icon-80x80.png",
      "scale" : "2x"
    },
    {
      "size" : "40x40",
      "idiom" : "iphone",
      "filename" : "icon-120x120.png",
      "scale" : "3x"
    },
    {
      "size" : "60x60",
      "idiom" : "iphone",
      "filename" : "icon-120x120.png",
      "scale" : "2x"
    },
    {
      "size" : "60x60",
      "idiom" : "iphone",
      "filename" : "icon-180x180.png",
      "scale" : "3x"
    },
    {
      "size" : "20x20",
      "idiom" : "ipad",
      "filename" : "icon-20x20.png",
      "scale" : "1x"
    },
    {
      "size" : "20x20",
      "idiom" : "ipad",
      "filename" : "icon-40x40.png",
      "scale" : "2x"
    },
    {
      "size" : "29x29",
      "idiom" : "ipad",
      "filename" : "icon-58x58.png",
      "scale" : "1x"
    },
    {
      "size" : "29x29",
      "idiom" : "ipad",
      "filename" : "icon-87x87.png",
      "scale" : "2x"
    },
    {
      "size" : "40x40",
      "idiom" : "ipad",
      "filename" : "icon-40x40.png",
      "scale" : "1x"
    },
    {
      "size" : "40x40",
      "idiom" : "ipad",
      "filename" : "icon-80x80.png",
      "scale" : "2x"
    },
    {
      "size" : "76x76",
      "idiom" : "ipad",
      "filename" : "icon-76x76.png",
      "scale" : "1x"
    },
    {
      "size" : "76x76",
      "idiom" : "ipad",
      "filename" : "icon-152x152.png",
      "scale" : "2x"
    },
    {
      "size" : "83.5x83.5",
      "idiom" : "ipad",
      "filename" : "icon-167x167.png",
      "scale" : "2x"
    },
    {
      "size" : "1024x1024",
      "idiom" : "ios-marketing",
      "filename" : "icon-1024x1024.png",
      "scale" : "1x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
EOF
echo "   ✅ Contents.json created"

# Generate Web icons
echo ""
echo "🌐 Generating Web icons..."
WEB_SIZES=(192 512)

for size in "${WEB_SIZES[@]}"; do
    output="web/icons/icon-${size}x${size}.png"
    $RESIZE_CMD "$LOGO" "$output" "$size"
    echo "   ✅ ${size}x${size}"
done

# Also create favicon sizes
$RESIZE_CMD "$LOGO" "web/icons/favicon-16x16.png" 16
$RESIZE_CMD "$LOGO" "web/icons/favicon-32x32.png" 32
$RESIZE_CMD "$LOGO" "web/icons/favicon-96x96.png" 96
echo "   ✅ Favicons created (16x16, 32x32, 96x96)"

# Update web manifest
echo ""
echo "📝 Updating web manifest..."
cat > web/manifest.json << EOF
{
    "name": "FlowGroove - Band Repertoire Manager",
    "short_name": "FlowGroove",
    "start_url": ".",
    "display": "standalone",
    "background_color": "#1A1A2E",
    "theme_color": "#1A1A2E",
    "description": "FlowGroove - Band Repertoire Management for Cover Bands",
    "orientation": "portrait-primary",
    "prefer_related_applications": false,
    "icons": [
        {
            "src": "icons/icon-192x192.png",
            "sizes": "192x192",
            "type": "image/png"
        },
        {
            "src": "icons/icon-512x512.png",
            "sizes": "512x512",
            "type": "image/png"
        },
        {
            "src": "icons/favicon-96x96.png",
            "sizes": "96x96",
            "type": "image/png"
        }
    ]
}
EOF
echo "   ✅ manifest.json updated"

# Create backup copies in assets
echo ""
echo "💾 Creating backup copies in assets/..."
cp android/app/src/main/res/mipmap-hdpi/ic_launcher.png assets/app_icons/android_hdpi.png
cp ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-1024x1024.png assets/app_icons/ios_1024.png
cp web/icons/icon-512x512.png assets/app_icons/web_512.png
echo "   ✅ Backup copies created"

# Summary
echo ""
echo "✅ Icon generation COMPLETE!"
echo ""
echo "📊 Generated icons:"
echo "   Android: ${#ANDROID_SIZES[@]} densities + adaptive icons"
echo "   iOS: ${#IOS_SIZES[@]} sizes"
echo "   Web: ${#WEB_SIZES[@]} main icons + 3 favicons"
echo ""
echo "📁 Output directories:"
echo "   - android/app/src/main/res/mipmap-*/"
echo "   - ios/Runner/Assets.xcassets/AppIcon.appiconset/"
echo "   - web/icons/"
echo "   - assets/app_icons/ (backup)"
echo ""
echo "📝 Next steps:"
echo "   1. Update AndroidManifest.xml (if needed)"
echo "   2. Update Info.plist (if needed)"
echo "   3. Test on devices"
echo ""
echo "🎨 Icons ready for deployment!"
