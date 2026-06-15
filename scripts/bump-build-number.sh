#!/bin/bash
# Bump the version in pubspec.yaml.
#
# Usage:
#   ./scripts/bump-build-number.sh           # +1 to build number (X.Y.Z+N -> X.Y.Z+N+1)
#   ./scripts/bump-build-number.sh patch     # X.Y.Z -> X.Y.(Z+1), build +1
#   ./scripts/bump-build-number.sh minor     # X.Y.Z -> X.(Y+1).0, build +1
#   ./scripts/bump-build-number.sh major     # X.Y.Z -> (X+1).0.0, build +1
#
# The build number is ALWAYS incremented (Android/Play require a strictly
# increasing versionCode), even when bumping a semver component.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBSPEC="$(dirname "$SCRIPT_DIR")/pubspec.yaml"
LEVEL="${1:-build}"

line="$(grep '^version:' "$PUBSPEC" || true)"
if [ -z "$line" ]; then
  echo "❌ ERROR: no 'version:' line found in $PUBSPEC" >&2
  exit 1
fi

current="${line#version: }"
current="${current// /}"           # strip stray spaces
base="${current%+*}"               # X.Y.Z
build="${current#*+}"              # N

if [ "$base" = "$current" ] || [ -z "$build" ]; then
  echo "❌ ERROR: version '$current' is not in X.Y.Z+N form" >&2
  exit 1
fi

IFS='.' read -r major minor patch <<EOF
$base
EOF

if [ -z "${major:-}" ] || [ -z "${minor:-}" ] || [ -z "${patch:-}" ]; then
  echo "❌ ERROR: semver part '$base' is not X.Y.Z" >&2
  exit 1
fi

case "$LEVEL" in
  build) ;;
  patch) patch=$((patch + 1)) ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  major) major=$((major + 1)); minor=0; patch=0 ;;
  *)
    echo "❌ ERROR: unknown level '$LEVEL' (use build|patch|minor|major)" >&2
    exit 1
    ;;
esac

new_build=$((build + 1))
new_version="${major}.${minor}.${patch}+${new_build}"

# Portable in-place edit (works on both macOS and Linux sed).
tmp="$(mktemp)"
sed "s/^version: .*/version: ${new_version}/" "$PUBSPEC" > "$tmp" && mv "$tmp" "$PUBSPEC"

echo "🔢 Bumped version: ${current} → ${new_version}"
