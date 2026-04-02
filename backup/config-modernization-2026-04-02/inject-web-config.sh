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

# Detect if running in non-interactive mode (CI/CD, automated scripts)
INTERACTIVE=true
if [ -n "$CI" ] || [ ! -t 0 ]; then
    INTERACTIVE=false
fi

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

# Load .env variables selectively (avoid exposing all vars)
export FIREBASE_API_KEY="${FIREBASE_API_KEY:-}"
export SPOTIFY_CLIENT_ID="${SPOTIFY_CLIENT_ID:-}"
export SPOTIFY_CLIENT_SECRET="${SPOTIFY_CLIENT_SECRET:-}"
export TWITTER_API_KEY="${TWITTER_API_KEY:-}"
export TWITTER_API_SECRET="${TWITTER_API_SECRET:-}"
export TRACK_ANALYSIS_API_KEY="${TRACK_ANALYSIS_API_KEY:-}"
export SPOTIFY_PROXY_URL="${SPOTIFY_PROXY_URL:-}"

# Check for required variables
MISSING_VARS=()

for var in FIREBASE_API_KEY SPOTIFY_CLIENT_ID SPOTIFY_CLIENT_SECRET; do
    value="${!var}"
    if [ -z "$value" ] || [[ "$value" == *"REPLACE_ME"* ]]; then
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
    
    # Handle interactive vs non-interactive mode
    if [ "$INTERACTIVE" = true ]; then
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Aborted. Please update .env file first."
            exit 1
        fi
    else
        echo "❌ ERROR: Running in non-interactive mode (CI/CD)."
        echo "   Required variables must be set before running this script."
        exit 1
    fi
fi

echo "📝 Creating web/config.js from template..."

# Copy template to output
cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

# Function to properly escape special characters for sed replacement
# Handles: & / \ [ ] ^ $ . * + ? { } ( ) |
escape_sed_replacement() {
    printf '%s\n' "$1" | sed 's/[&/\[\]^$.*+?{}()|\\]/\\&/g'
}

# Replace placeholders with actual values
# Using sed with different delimiters to handle special chars in values

if [ -n "$FIREBASE_API_KEY" ]; then
    ESCAPED_VALUE=$(escape_sed_replacement "$FIREBASE_API_KEY")
    sed -i.bak "s|FIREBASE_API_KEY: ''|FIREBASE_API_KEY: '$ESCAPED_VALUE'|g" "$OUTPUT_FILE"
fi

if [ -n "$SPOTIFY_CLIENT_ID" ]; then
    ESCAPED_VALUE=$(escape_sed_replacement "$SPOTIFY_CLIENT_ID")
    sed -i.bak "s|SPOTIFY_CLIENT_ID: ''|SPOTIFY_CLIENT_ID: '$ESCAPED_VALUE'|g" "$OUTPUT_FILE"
fi

if [ -n "$SPOTIFY_CLIENT_SECRET" ]; then
    ESCAPED_VALUE=$(escape_sed_replacement "$SPOTIFY_CLIENT_SECRET")
    sed -i.bak "s|SPOTIFY_CLIENT_SECRET: ''|SPOTIFY_CLIENT_SECRET: '$ESCAPED_VALUE'|g" "$OUTPUT_FILE"
fi

if [ -n "$TWITTER_API_KEY" ]; then
    ESCAPED_VALUE=$(escape_sed_replacement "$TWITTER_API_KEY")
    sed -i.bak "s|TWITTER_API_KEY: ''|TWITTER_API_KEY: '$ESCAPED_VALUE'|g" "$OUTPUT_FILE"
fi

if [ -n "$TWITTER_API_SECRET" ]; then
    ESCAPED_VALUE=$(escape_sed_replacement "$TWITTER_API_SECRET")
    sed -i.bak "s|TWITTER_API_SECRET: ''|TWITTER_API_SECRET: '$ESCAPED_VALUE'|g" "$OUTPUT_FILE"
fi

if [ -n "$TRACK_ANALYSIS_API_KEY" ]; then
    ESCAPED_VALUE=$(escape_sed_replacement "$TRACK_ANALYSIS_API_KEY")
    sed -i.bak "s|TRACK_ANALYSIS_API_KEY: ''|TRACK_ANALYSIS_API_KEY: '$ESCAPED_VALUE'|g" "$OUTPUT_FILE"
fi

if [ -n "$SPOTIFY_PROXY_URL" ]; then
    ESCAPED_VALUE=$(escape_sed_replacement "$SPOTIFY_PROXY_URL")
    sed -i.bak "s|// SPOTIFY_PROXY_URL=|SPOTIFY_PROXY_URL=|g" "$OUTPUT_FILE"
    sed -i.bak "s|SPOTIFY_PROXY_URL=''|SPOTIFY_PROXY_URL='$ESCAPED_VALUE'|g" "$OUTPUT_FILE"
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
