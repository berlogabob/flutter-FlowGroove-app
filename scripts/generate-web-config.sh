#!/bin/bash
# shellcheck shell=bash
# Generate runtime web configuration from exported vars and local non-tracked env files.
# Usage: ./scripts/generate-web-config.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_FILE="$PROJECT_ROOT/web/config.template.js"
OUTPUT_FILE="$PROJECT_ROOT/web/config.js"
BUILD_OUTPUT="$PROJECT_ROOT/build/web/config.js"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/load-deploy-env.sh"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║      Generating Web Configuration                         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ ERROR: Template file not found at $TEMPLATE_FILE"
    exit 1
fi

flowgroove_print_loaded_sources
echo ""

# Export public runtime values explicitly so envsubst always produces a full file.
export FIREBASE_API_KEY="${FIREBASE_API_KEY:-}"
export SPOTIFY_PROXY_URL="${SPOTIFY_PROXY_URL:-}"

# Validate required environment variables
flowgroove_require_vars FIREBASE_API_KEY

echo "📄 Building runtime config from local env sources and exported variables..."
echo ""

SUBSTITUTION_VARS='${FIREBASE_API_KEY} ${SPOTIFY_PROXY_URL}'

# Replace placeholders using envsubst for safe variable substitution
# This handles special characters automatically
if command -v envsubst >/dev/null 2>&1; then
    echo "🔄 Using envsubst for safe variable substitution..."
    envsubst "$SUBSTITUTION_VARS" < "$TEMPLATE_FILE" > "${OUTPUT_FILE}.tmp"
    mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
else
    echo "⚠️  envsubst not found, falling back to sed (less safe)"
    echo "   Install gettext package for better support"
    echo ""

    cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

    # Fallback to sed with proper escaping
    for var in FIREBASE_API_KEY SPOTIFY_PROXY_URL; do
        value="${!var}"
        escaped=$(printf '%s\n' "$value" | sed 's/[&/\[\]^$.*+?{}()|\\]/\\&/g')
        sed -i.bak "s|\${${var}}|${escaped}|g" "$OUTPUT_FILE"
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
echo "   - web/config.js is a generated runtime artifact - DO NOT COMMIT"
echo "   - This file should be in .gitignore"
echo "   - Web runtime config must stay public-only; keep privileged API secrets off the client"
echo ""
