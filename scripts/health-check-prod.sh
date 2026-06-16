#!/usr/bin/env bash
# Post-deployment health check for flowgroove.app.
#
# Keep this logic outside the Makefile: GNU Make executes recipe lines that
# contain $(MAKE) even during `make -n`, which can turn CI dry-runs into real
# production health checks or rollbacks.

set -euo pipefail

BACKUP_INFO_FILE="${BACKUP_INFO_FILE:-/tmp/flowgroove-latest-backup.txt}"

rollback() {
  echo "🚨 Auto-rollback initiated..."
  make auto-rollback
}

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Running Post-Deployment Health Check              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "🔍 Checking production site..."
sleep 5  # Wait for CDN propagation.

echo "📊 Checking Hugo landing page..."
if curl -f -s https://flowgroove.app/ > /dev/null; then
  echo "✅ Hugo landing page is accessible"
else
  echo "❌ ERROR: Hugo landing page is not accessible!"
  rollback
  exit 1
fi

echo "📊 Checking Flutter app..."
if curl -f -s https://flowgroove.app/app/ > /dev/null; then
  echo "✅ Flutter app is accessible"
else
  echo "❌ ERROR: Flutter app is not accessible!"
  rollback
  exit 1
fi

echo "📊 Checking config.js..."
if curl -f -s https://flowgroove.app/app/config.js | grep -q "FIREBASE_API_KEY"; then
  echo "✅ config.js is present and valid"
else
  echo "❌ ERROR: config.js missing or invalid!"
  rollback
  exit 1
fi

echo "📊 Checking sensitive files..."
if curl -f -s https://flowgroove.app/.env > /dev/null; then
  echo "❌ ERROR: Sensitive .env is publicly accessible!"
  rollback
  exit 1
else
  echo "✅ Sensitive .env is not publicly accessible"
fi

echo "✅ Health check passed"
echo ""
BACKUP_DIR="$(cat "$BACKUP_INFO_FILE" 2>/dev/null || echo 'N/A')"
echo "💾 Backup retained at: $BACKUP_DIR"
echo "   (for manual rollback if issues discovered later)"
echo ""
