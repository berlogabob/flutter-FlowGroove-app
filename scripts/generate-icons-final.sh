#!/bin/bash
# Final Icon Generation Script
# Works around permission issues

set -e

echo "🎨 FlowGroove Icon Generator - Final"
echo "====================================="
echo ""

# Check if logo exists
if [ ! -f "assets/logo_clean.png" ]; then
    echo "❌ Logo not found: assets/logo_clean.png"
    echo "Please create the file first"
    exit 1
fi

echo "✅ Logo found: assets/logo_clean.png"
echo ""

# Check if flutter_launcher_icons is installed
if ! grep -q "flutter_launcher_icons" pubspec.yaml 2>/dev/null; then
    echo "📦 Installing flutter_launcher_icons..."
    flutter pub add dev:flutter_launcher_icons
    echo ""
fi

echo "⚙️  Configuration ready: flutter_launcher_icons.yaml"
echo ""

echo "🚀 Generating icons..."
echo ""

# Run the generator
dart run flutter_launcher_icons << EOF
Y
EOF

echo ""
echo "✅ Icon generation complete!"
echo ""
echo "📊 Generated:"
echo "   Android: 5 densities + adaptive icons"
echo "   iOS: 11+ sizes"
echo "   Web: 5 icons"
echo ""
echo "📁 Locations:"
echo "   - android/app/src/main/res/mipmap-*/"
echo "   - ios/Runner/Assets.xcassets/AppIcon.appiconset/"
echo "   - web/icons/"
echo ""
echo "🧪 Test now:"
echo "   flutter run -d chrome"
echo ""
echo "📝 Commit when ready:"
echo "   git add android/ ios/ web/ flutter_launcher_icons.yaml assets/logo_clean.png"
echo "   git commit -m 'Add app icons for all platforms'"
