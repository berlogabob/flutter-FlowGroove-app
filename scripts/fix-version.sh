#!/bin/bash
# Fix version.json after Flutter web build
# Flutter has a caching issue that doesn't pick up the latest version from pubspec.yaml

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Extract version from pubspec.yaml
VERSION_LINE=$(grep '^version:' pubspec.yaml)
VERSION=$(echo "$VERSION_LINE" | awk '{print $2}' | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$VERSION_LINE" | awk '{print $2}' | cut -d'+' -f2)

# Create version.json
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Ensure build/web directory exists
mkdir -p build/web

cat > build/web/version.json << EOF
{
  "version": "$VERSION",
  "buildNumber": "$BUILD_NUMBER",
  "buildDate": "$BUILD_DATE"
}
EOF

# Also update docs if it exists
if [ -d "docs" ]; then
  cp build/web/version.json docs/version.json
fi

echo "✅ version.json fixed:"
echo "   Version: $VERSION+$BUILD_NUMBER"
echo "   Build Date: $BUILD_DATE"
