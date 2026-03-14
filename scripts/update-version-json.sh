#!/bin/bash
# Update version.json with current version from pubspec.yaml
# Usage: ./scripts/update-version-json.sh

set -e

echo "📝 Updating version.json..."

# Read version from pubspec.yaml
VERSION_LINE=$(grep "^version:" pubspec.yaml)
VERSION=$(echo $VERSION_LINE | sed 's/version: \([0-9.]*\)+.*/\1/')
BUILD_NUMBER=$(echo $VERSION_LINE | sed 's/version: .*+\([0-9]*\)/\1/')

# Get current time in Lisbon timezone
LISBON_TIME=$(TZ="Europe/Lisbon" date +"%Y-%m-%dT%H:%M:%SZ")

# Update web/version.json
cat > web/version.json << EOF
{
  "version": "$VERSION",
  "buildNumber": "$BUILD_NUMBER",
  "buildDate": "$LISBON_TIME"
}
EOF

echo "✅ version.json updated:"
cat web/version.json
echo ""
echo "Version: $VERSION+$BUILD_NUMBER"
echo "Build Time: $LISBON_TIME"
