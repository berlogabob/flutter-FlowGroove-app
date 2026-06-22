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

# Guard: a release APK that escapes to GitHub/Obtainium MUST be signed with the
# stable upload key. A missing (gitignored) android/key.properties silently
# falls back to an ephemeral debug key — different signature every build, which
# breaks app updates (INSTALL_FAILED_UPDATE_INCOMPATIBLE) and Google Sign-In
# (unregistered SHA). Verify the real output cert, not just that key.properties
# exists. Override the expected digest on a key rotation (also re-register SHAs).
# ponytail: APK only; AAB is re-signed by Play so its local signature is moot.
if [ "$TARGET" = "apk" ]; then
    EXPECTED_APK_CERT_SHA256="${EXPECTED_APK_CERT_SHA256:-4ef0bb90641050755a0659a6a70f819e2787549ff6746c7703c6ae92ed0785de}"
    APK_PATH="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
    # `|| true`: find returns non-zero on any missing search dir, which under
    # `set -euo pipefail` would abort the script before we check anything.
    APKSIGNER="$(find "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}" "$HOME/Android/Sdk" -name apksigner 2>/dev/null | sort | tail -1 || true)"
    if [ -z "$APKSIGNER" ]; then
        echo "❌ ERROR: apksigner not found — cannot verify release signing." >&2
        exit 1
    fi
    GOT="$("$APKSIGNER" verify --print-certs "$APK_PATH" 2>/dev/null \
        | sed -n 's/.*certificate SHA-256 digest: //p' | head -1 || true)"
    if [ "$GOT" != "$EXPECTED_APK_CERT_SHA256" ]; then
        echo "❌ ERROR: release APK signed with '$GOT', expected stable upload key" >&2
        echo "   '$EXPECTED_APK_CERT_SHA256'. Likely android/key.properties is missing" >&2
        echo "   in this environment (it is gitignored). Refusing to publish a" >&2
        echo "   debug-signed APK that would break updates and Google Sign-In." >&2
        exit 1
    fi
    echo "🔏 Release APK signature verified against stable upload key."
fi
