#!/bin/bash
# Inject Web Configuration from .env into web/config.js
# Usage: ./scripts/inject-web-config.sh
#
# This script:
# 1. Reads credentials from .env file
# 2. Copies web/config.js.template to web/config.js
# 3. Replaces placeholders with actual values
# 4. Copies to build/web/config.js if build exists

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"
TEMPLATE_FILE="$PROJECT_ROOT/web/config.js.template"
OUTPUT_FILE="$PROJECT_ROOT/web/config.js"
BUILD_OUTPUT="$PROJECT_ROOT/build/web/config.js"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Injecting Web Configuration from .env             ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "⚠️  WARNING: .env file not found at $ENV_FILE"
    echo "   Creating from .env.example..."
    if [ -f "$PROJECT_ROOT/.env.example" ]; then
        cp "$PROJECT_ROOT/.env.example" "$ENV_FILE"
        echo "✅ Created .env from template"
        echo ""
        echo "🔧 ACTION REQUIRED: Edit .env file with your credentials:"
        echo "   1. Open $ENV_FILE"
        echo "   2. Replace REPLACE_ME_* placeholders with actual values"
        echo "   3. Run this script again"
        echo ""
        exit 1
    else
        echo "❌ ERROR: .env.example not found either!"
        exit 1
    fi
fi

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ ERROR: Template file not found at $TEMPLATE_FILE"
    exit 1
fi

echo "📄 Reading .env file..."
echo ""

# Load .env variables (safely, ignoring comments and empty lines)
set -a
source "$ENV_FILE"
set +a

# Check for required variables
REQUIRED_VARS=("FIREBASE_API_KEY" "SPOTIFY_CLIENT_ID" "SPOTIFY_CLIENT_SECRET")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ] || [[ "${!var}" == *"REPLACE_ME"* ]]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "⚠️  WARNING: The following required variables are missing or still have placeholder values:"
    for var in "${MISSING_VARS[@]}"; do
        echo "   - $var"
    done
    echo ""
    echo "🔧 ACTION REQUIRED: Edit .env file and set these values:"
    echo "   $ENV_FILE"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Aborted. Please update .env file first."
        exit 1
    fi
fi

echo "📝 Creating web/config.js from template..."

# Copy template to output
cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

# Replace placeholders with actual values
# Using sed with different delimiters to handle special chars in values

if [ -n "$FIREBASE_API_KEY" ]; then
    sed -i.bak "s|FIREBASE_API_KEY: ''|FIREBASE_API_KEY: '$FIREBASE_API_KEY'|g" "$OUTPUT_FILE"
fi

if [ -n "$SPOTIFY_CLIENT_ID" ]; then
    sed -i.bak "s|SPOTIFY_CLIENT_ID: ''|SPOTIFY_CLIENT_ID: '$SPOTIFY_CLIENT_ID'|g" "$OUTPUT_FILE"
fi

if [ -n "$SPOTIFY_CLIENT_SECRET" ]; then
    # Escape special characters in secret for sed
    ESCAPED_SECRET=$(echo "$SPOTIFY_CLIENT_SECRET" | sed 's/[&/\]/\\&/g')
    sed -i.bak "s|SPOTIFY_CLIENT_SECRET: ''|SPOTIFY_CLIENT_SECRET: '$ESCAPED_SECRET'|g" "$OUTPUT_FILE"
fi

if [ -n "$TWITTER_API_KEY" ]; then
    sed -i.bak "s|TWITTER_API_KEY: ''|TWITTER_API_KEY: '$TWITTER_API_KEY'|g" "$OUTPUT_FILE"
fi

if [ -n "$TWITTER_API_SECRET" ]; then
    ESCAPED_SECRET=$(echo "$TWITTER_API_SECRET" | sed 's/[&/\]/\\&/g')
    sed -i.bak "s|TWITTER_API_SECRET: ''|TWITTER_API_SECRET: '$ESCAPED_SECRET'|g" "$OUTPUT_FILE"
fi

if [ -n "$TRACK_ANALYSIS_API_KEY" ]; then
    sed -i.bak "s|TRACK_ANALYSIS_API_KEY: ''|TRACK_ANALYSIS_API_KEY: '$TRACK_ANALYSIS_API_KEY'|g" "$OUTPUT_FILE"
fi

if [ -n "$SPOTIFY_PROXY_URL" ]; then
    sed -i.bak "s|// SPOTIFY_PROXY_URL=|SPOTIFY_PROXY_URL=|g" "$OUTPUT_FILE"
    sed -i.bak "s|SPOTIFY_PROXY_URL=''|SPOTIFY_PROXY_URL='$SPOTIFY_PROXY_URL'|g" "$OUTPUT_FILE"
fi

# Remove backup file created by sed
rm -f "$OUTPUT_FILE.bak"

echo "✅ web/config.js created successfully"
echo ""

# Copy to build directory if it exists
if [ -d "$PROJECT_ROOT/build/web" ]; then
    echo "📦 Copying to build/web/config.js..."
    cp "$OUTPUT_FILE" "$BUILD_OUTPUT"
    echo "✅ build/web/config.js updated"
    echo ""
fi

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              ✅ Configuration Injected                    ║"
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
echo "   - .env file is gitignored - keep it secure"
echo "   - Never share your config.js or .env files"
echo ""
