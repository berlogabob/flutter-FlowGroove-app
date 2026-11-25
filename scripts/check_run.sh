#!/usr/bin/env bash
# Cross-platform check run: scripts/check_run.sh <android|ios|web> [device-id]
# Starts the Firebase emulators if needed, seeds them, runs integration_test/check
# through `flutter drive`, leaves build/check/<platform>.json.
set -euo pipefail

PLATFORM="${1:?usage: check_run.sh <android|ios|web> [device-id]}"
DEVICE="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PROJECT=repsync-app-8685c
ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
CHROMEDRIVER_PORT=4444
STARTED=()
cleanup() { for pid in "${STARTED[@]:-}"; do [ -n "$pid" ] && kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

# --- emulators (need JDK 21+) ---
if ! curl -s localhost:8080 >/dev/null; then
  export JAVA_HOME="$(/usr/libexec/java_home -v 21+)" PATH="$(/usr/libexec/java_home -v 21+)/bin:$PATH"
  mkdir -p build/check
  CONFIG=firebase.json
  if [ "$PLATFORM" = ios ]; then
    # The iPad reaches the emulators over the LAN, so they must not bind to localhost only.
    CONFIG=build/check/firebase.ios.json
    uv run python -c "import json; c=json.load(open('firebase.json')); [e.update(host='0.0.0.0') for e in c['emulators'].values() if isinstance(e, dict)]; json.dump(c, open('$CONFIG','w'))"
  fi
  firebase emulators:start --config "$CONFIG" --project "$PROJECT" --only auth,firestore,storage >build/check/emulators.log 2>&1 &
  STARTED+=($!)
  for _ in $(seq 60); do curl -s localhost:8080 >/dev/null && curl -s localhost:9099 >/dev/null && curl -s localhost:9199 >/dev/null && break; sleep 1; done
fi

# --- per-platform: how the app reaches the emulators, and the drive target ---
DEFINES=()
case "$PLATFORM" in
  android)
    DEVICE="${DEVICE:-XPH0219904001750}"
    # firebase_core rewrites localhost/127.0.0.1 to the Android emulator's 10.0.2.2, which a
    # real phone cannot reach; 0.0.0.0 is not rewritten and reaches the adb-reverse listener.
    HOST=0.0.0.0
    for port in 9099 8080 9199; do "$ADB" -s "$DEVICE" reverse tcp:$port tcp:$port; done
    ;;
  ios)
    : "${DEVICE:?ios needs a device id (flutter devices)}"
    HOST="$(ipconfig getifaddr en0)"   # the iPad reaches the Mac over the LAN
    ;;
  web)
    DEVICE=chrome
    HOST=127.0.0.1
    CHROMEDRIVER="${CHROMEDRIVER:-$(ls build/check-tools/chromedriver/*/chromedriver-*/chromedriver 2>/dev/null | head -1)}"
    if [ -z "$CHROMEDRIVER" ]; then
      (cd build/check-tools 2>/dev/null || { mkdir -p build/check-tools && cd build/check-tools; }
       VER="$("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --version | awk '{print $3}')"
       npx --yes @puppeteer/browsers install "chromedriver@$VER")
      CHROMEDRIVER="$(ls build/check-tools/chromedriver/*/chromedriver-*/chromedriver | head -1)"
    fi
    "$CHROMEDRIVER" --port=$CHROMEDRIVER_PORT >build/check/chromedriver.log 2>&1 &
    STARTED+=($!)
    sleep 1
    WRAP="$(mktemp -d)/chrome-autoplay.sh"   # outside the repo: chromedriver may not exec scripts from it
    # Synthetic taps are not user activation, so Chrome would refuse audio.play(): lift that policy.
    printf '#!/bin/bash\nexec "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --autoplay-policy=no-user-gesture-required "$@"\n' > "$WRAP"
    chmod +x "$WRAP"
    DEFINES=(--browser-dimension=480x900 --chrome-binary="$WRAP")
    ;;
  *) echo "unknown platform $PLATFORM" >&2; exit 2 ;;
esac

# This Mac's Xcode needs `sudo xcodebuild -runFirstLaunch`; until then `xcrun simctl` hangs
# forever and with it every flutter device listing. Android and web never need simctl,
# so answer simctl and devicectl with a failure through a PATH shim and pass everything else through.
if [ "$PLATFORM" != ios ]; then
  mkdir -p build/check-tools/shim
  printf '#!/bin/bash\ncase "$1" in simctl|devicectl) exit 1;; esac\nexec /usr/bin/xcrun "$@"\n' > build/check-tools/shim/xcrun
  chmod +x build/check-tools/shim/xcrun
  export PATH="$ROOT/build/check-tools/shim:$PATH"
fi

uv run python scripts/check_seed.py "$HOST"

rm -f "build/check/$PLATFORM.json"
CHECK_PLATFORM="$PLATFORM" flutter drive \
  --driver=test_driver/check_driver.dart \
  --target=integration_test/check/check_test.dart \
  -d "$DEVICE" \
  --dart-define=EMULATOR_HOST="$HOST" \
  ${CHECK_ONLY:+--dart-define=CHECK_ONLY="$CHECK_ONLY"} \
  ${DEFINES[@]+"${DEFINES[@]}"} </dev/null

test -f "build/check/$PLATFORM.json" && echo "wrote build/check/$PLATFORM.json"
