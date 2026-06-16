#!/bin/bash
# shellcheck shell=bash
#
# Build mobile artifacts using compile-time dart-defines instead of bundled env assets.
# Usage: ./scripts/build-mobile-with-env.sh apk|appbundle

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"
DEMO_FILE="$PROJECT_ROOT/assets/env.demo.json"

if [ $# -ne 1 ]; then
    echo "Usage: $0 apk|appbundle" >&2
    exit 1
fi

TARGET="$1"
case "$TARGET" in
    apk|appbundle)
        ;;
    *)
        echo "❌ ERROR: Unsupported mobile build target: $TARGET" >&2
        exit 1
        ;;
esac

source_env_file() {
    local env_file="$1"
    set -a
    # shellcheck disable=SC1090
    . "$env_file"
    set +a
}

is_placeholder() {
    case "${1:-}" in
        ""|REPLACE_ME*|YOUR_*|your_*|CHANGE_ME*|changeme|example|EXAMPLE)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

if [ -f "$ENV_FILE" ]; then
    source_env_file "$ENV_FILE"
    SOURCE_LABEL="$ENV_FILE"
else
    source_env_file "$DEMO_FILE"
    SOURCE_LABEL="$DEMO_FILE"
fi

# Android Studio exposes its JDK under jbr/Contents/Home on macOS. Accept the
# bundle root in local env files while exporting the path Gradle expects.
if [ -n "${JAVA_HOME:-}" ] && [ ! -x "$JAVA_HOME/bin/java" ] && [ -x "$JAVA_HOME/Contents/Home/bin/java" ]; then
    export JAVA_HOME="$JAVA_HOME/Contents/Home"
fi

if is_placeholder "${FIREBASE_API_KEY:-}"; then
    echo "❌ ERROR: FIREBASE_API_KEY is missing for mobile build" >&2
    exit 1
fi

echo "📄 Building mobile target using compile-time defines from:"
echo "   $SOURCE_LABEL"

build_cmd=(flutter build "$TARGET" --release)

add_define() {
    local key="$1"
    local value="${!key:-}"
    if ! is_placeholder "$value"; then
        build_cmd+=("--dart-define=$key=$value")
    fi
}

for key in \
    FIREBASE_API_KEY \
    SPOTIFY_CLIENT_ID \
    SPOTIFY_CLIENT_SECRET \
    SPOTIFY_PROXY_URL \
    TWITTER_API_KEY \
    TWITTER_API_SECRET \
    TELEGRAM_BOT_TOKEN
do
    add_define "$key"
done

"${build_cmd[@]}"
