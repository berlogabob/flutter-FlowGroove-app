#!/bin/bash
# shellcheck shell=bash
#
# Preflight gate for production FTP deploys.
# Verifies local env, tracked examples, and staged changes before any upload.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/load-deploy-env.sh"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Production FTP Preflight Check                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

flowgroove_print_loaded_sources
flowgroove_require_vars FIREBASE_API_KEY FTP_HOST FTP_USER FTP_PASS

assert_placeholder_setting() {
    local file="$1"
    local key="$2"

    if [ ! -f "$file" ]; then
        echo "❌ ERROR: Required example file missing: $file"
        exit 1
    fi

    if ! grep -Eq "^${key}=REPLACE_ME_[A-Z0-9_]+$" "$file"; then
        echo "❌ ERROR: $file must keep $key as a placeholder-only value"
        exit 1
    fi
}

assert_placeholder_setting "$PROJECT_ROOT/.env.example" FTP_HOST
assert_placeholder_setting "$PROJECT_ROOT/.env.example" FTP_USER
assert_placeholder_setting "$PROJECT_ROOT/.env.example" FTP_PASS
assert_placeholder_setting "$PROJECT_ROOT/.ftp-env.example" FTP_HOST
assert_placeholder_setting "$PROJECT_ROOT/.ftp-env.example" FTP_USER
assert_placeholder_setting "$PROJECT_ROOT/.ftp-env.example" FTP_PASS
assert_placeholder_setting "$PROJECT_ROOT/.ftp-env.example" FTP_DIR

if git -C "$PROJECT_ROOT" ls-files --error-unmatch web/config.js >/dev/null 2>&1; then
    echo "❌ ERROR: web/config.js is still tracked in git"
    echo "   Remove it from the index before production deploys."
    exit 1
fi

if ! git -C "$PROJECT_ROOT" check-ignore -q web/config.js; then
    echo "❌ ERROR: web/config.js is not gitignored"
    exit 1
fi

BLOCKED_STAGED="$(git -C "$PROJECT_ROOT" diff --cached --name-only --diff-filter=ACMR -- . | \
    grep -E '^(\.env($|\.)|\.ftp-env$|web/config\.js$|assets/env\.json$|backup/|chat-exports-collection/|oldarchive/|qwen-code-export-)' | \
    grep -Ev '^oldarchive/README\.md$' || true)"

if [ -n "$BLOCKED_STAGED" ]; then
    echo "❌ ERROR: Blocked paths are staged for commit:"
    echo "$BLOCKED_STAGED" | sed 's/^/   - /'
    echo "   Clear these before production deploy."
    exit 1
fi

SECRET_STAGED="$(git -C "$PROJECT_ROOT" diff --cached -U0 -- . \
    ':!*.example' \
    ':!*.demo.js' \
    ':!assets/env.demo.json' \
    ':!docs/**' \
    ':!oldarchive/**' 2>/dev/null | \
    grep -E '^\+.*(FTP_PASS=|SPOTIFY_CLIENT_SECRET=|SPOTIFY_CLIENT_ID=|TWITTER_API_KEY=|TWITTER_API_SECRET=|TRACK_ANALYSIS_API_KEY=|TELEGRAM_BOT_TOKEN=|FIREBASE_API_KEY=)' || true)"

if [ -n "$SECRET_STAGED" ]; then
    echo "❌ ERROR: Staged diff includes potential credential-bearing additions:"
    echo "$SECRET_STAGED" | sed -E 's/(=.*)$/=[REDACTED]/' | sed 's/^/   /'
    exit 1
fi

echo "✅ Preflight passed"
echo ""
