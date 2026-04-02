#!/bin/bash
# Generate Web Configuration for CI/CD
# Usage: ./scripts/generate-web-config.sh
#
# This script is designed for CI/CD pipelines (GitHub Actions, GitLab CI, etc.)
# It reads environment variables and generates web/config.js directly
#
# Required Environment Variables:
#   FIREBASE_API_KEY
#   SPOTIFY_CLIENT_ID
#   SPOTIFY_CLIENT_SECRET
#
# Optional Environment Variables:
#   TWITTER_API_KEY
#   TWITTER_API_SECRET
#   TRACK_ANALYSIS_API_KEY
#   SPOTIFY_PROXY_URL

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_FILE="$PROJECT_ROOT/web/config.template.js"
OUTPUT_FILE="$PROJECT_ROOT/web/config.js"
BUILD_OUTPUT="$PROJECT_ROOT/build/web/config.js"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║      Generating Web Configuration (CI/CD Mode)            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check if running in CI/CD environment
if [ -z "$CI" ] && [ -t 0 ]; then
    echo "⚠️  WARNING: Not running in CI/CD environment"
    echo "   This script is designed for automated pipelines"
    echo "   For local development, use: ./scripts/inject-web-config.sh"
    echo ""
fi

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ ERROR: Template file not found at $TEMPLATE_FILE"
    exit 1
fi

# Validate required environment variables
REQUIRED_VARS=("FIREBASE_API_KEY" "SPOTIFY_CLIENT_ID" "SPOTIFY_CLIENT_SECRET")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "❌ ERROR: Missing required environment variables:"
    for var in "${MISSING_VARS[@]}"; do
        echo "   - $var"
    done
    echo ""
    echo "   Set these in your CI/CD secrets or environment before running"
    exit 1
fi

echo "📄 Using environment variables for configuration..."
echo ""

# Copy template to output
cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

# Replace placeholders using envsubst for safe variable substitution
# This handles special characters automatically
if command -v envsubst >/dev/null 2>&1; then
    echo "🔄 Using envsubst for safe variable substitution..."
    envsubst < "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp"
    mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
else
    echo "⚠️  envsubst not found, falling back to sed (less safe)"
    echo "   Install gettext package for better support"
    echo ""
    
    # Fallback to sed with proper escaping
    for var in "${REQUIRED_VARS[@]}" TWITTER_API_KEY TWITTER_API_SECRET TRACK_ANALYSIS_API_KEY SPOTIFY_PROXY_URL; do
        value="${!var}"
        if [ -n "$value" ]; then
            # Escape special characters for sed
            escaped=$(printf '%s\n' "$value" | sed 's/[&/\[\]^$.*+?{}()|\\]/\\&/g')
            sed -i.bak "s|\${${var}}|${escaped}|g" "$OUTPUT_FILE"
        fi
    done
    rm -f "$OUTPUT_FILE.bak"
fi

echo "✅ web/config.js generated successfully"
echo ""

# Copy to build directory if it exists
if [ -d "$PROJECT_ROOT/build/web" ]; then
    echo "📦 Copying to build/web/config.js..."
    cp "$OUTPUT_FILE" "$BUILD_OUTPUT"
    echo "✅ build/web/config.js updated"
    echo ""
fi

# Validate generated config (basic check)
if grep -q '\${' "$OUTPUT_FILE"; then
    echo "❌ ERROR: Some placeholders were not replaced!"
    echo "   Check your environment variables"
    grep '\${' "$OUTPUT_FILE"
    exit 1
fi

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              ✅ Configuration Generated                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Summary:"
echo "   Template: $TEMPLATE_FILE"
echo "   Output:   $OUTPUT_FILE"
if [ -d "$PROJECT_ROOT/build/web" ]; then
    echo "   Build:    $BUILD_OUTPUT ✅"
else
    echo "   Build:    (build/web not found - will copy after build)"
fi
echo ""
echo "⚠️  SECURITY REMINDER:"
echo "   - web/config.js contains secrets - DO NOT COMMIT"
echo "   - This file should be in .gitignore"
echo "   - Never share your config.js file"
echo ""
