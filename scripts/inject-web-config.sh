#!/bin/bash
# shellcheck shell=bash
# Generate public-only web/config.js from local non-tracked env files.
# Usage: ./scripts/inject-web-config.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Injecting Web Runtime Configuration               ║"
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

echo "📄 Using .env as the primary local source"
echo "   Optional FTP overrides can live in .ftp-env"
echo "   Only public web runtime values are emitted into web/config.js"
echo ""
"$SCRIPT_DIR/generate-web-config.sh"
