#!/bin/bash

# Build script for RepSync Flutter Web App
# Automatically updates version.json with current Lisbon time

set -e

echo "🔨 Building RepSync..."

# Read version from pubspec.yaml (DO NOT MODIFY)
VERSION_LINE=$(grep "^version:" pubspec.yaml)
VERSION=$(echo $VERSION_LINE | sed 's/version: \([0-9.]*\)+.*/\1/')
BUILD_NUMBER=$(echo $VERSION_LINE | sed 's/version: .*+\([0-9]*\)/\1/')

echo "📦 Version: $VERSION+$BUILD_NUMBER"

# Get current time in Lisbon timezone
LISBON_TIME=$(TZ="Europe/Lisbon" date +"%Y-%m-%dT%H:%M:%SZ")
echo "🕐 Build Time (Lisbon): $LISBON_TIME"

# Update web/version.json
cat > web/version.json << EOF
{
  "version": "$VERSION",
  "buildNumber": "$BUILD_NUMBER",
  "buildDate": "$LISBON_TIME"
}
EOF

echo "✅ version.json updated"

# Clean and build
flutter clean
flutter build web --release --base-href "/flutter-repsync-app/"

# Deploy to docs
rm -rf docs
mkdir -p docs
cp -r build/web/. docs/
touch docs/.nojekyll
cp docs/index.html docs/404.html

echo "✅ Build complete!"
echo "📂 Deployed to docs/"
echo "🌐 Version: $VERSION+$BUILD_NUMBER"
echo "🕐 Build time: $LISBON_TIME"
