#!/bin/bash
# scripts/inject-android-config.sh
# Injects Firebase config into Android build

set -e

echo "🔧 Injecting Firebase config for Android build..."

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ Error: .env file not found!"
    echo "Please create .env file with your Firebase API key:"
    echo "  FIREBASE_API_KEY=your_api_key_here"
    exit 1
fi

# Check if FIREBASE_API_KEY is set
if ! grep -q "FIREBASE_API_KEY=" ".env"; then
    echo "❌ Error: FIREBASE_API_KEY not set in .env file!"
    exit 1
fi

# Extract the API key (remove quotes and whitespace)
API_KEY=$(grep "FIREBASE_API_KEY=" ".env" | cut -d'=' -f2 | tr -d '"' | tr -d ' ' | tr -d "'")

if [ -z "$API_KEY" ] || [ "$API_KEY" = "your_firebase_api_key_here" ]; then
    echo "❌ Error: FIREBASE_API_KEY is not set or still has placeholder value!"
    exit 1
fi

echo "✅ Firebase API key found (masked): ${API_KEY:0:10}..."

# Update build.gradle.kts with the API key
GRADLE_FILE="android/app/build.gradle.kts"

# Create backup
if [ ! -f "$GRADLE_FILE.backup" ]; then
    cp "$GRADLE_FILE" "$GRADLE_FILE.backup"
fi

# Update the buildConfigField value
sed -i.tmp "s/buildConfigField(\"String\", \"FIREBASE_API_KEY\", \"\\\".*\\\"\")/buildConfigField(\"String\", \"FIREBASE_API_KEY\", \"\\\"$API_KEY\\\"\")/" "$GRADLE_FILE"
rm -f "$GRADLE_FILE.tmp"

echo "✅ Firebase config injected into Android build"
echo "📱 Ready to build Android release!"
echo ""
echo "Next steps:"
echo "  flutter build apk --release"
echo "  or"
echo "  flutter build appbundle --release"
