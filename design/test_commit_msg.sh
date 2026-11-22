#!/bin/bash
set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/.githooks/commit-msg"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

setup_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.name "Test User"
  git -C "$dir" config user.email "test@example.invalid"
  git -C "$dir" config commit.gpgsign false
  mkdir -p "$dir/design/figcraft/specs"
  printf '{"v":1}\n' > "$dir/design/figcraft/specs/screen.json"
  git -C "$dir" add .
  git -C "$dir" commit -qm baseline
  mkdir -p "$dir/.git/hooks"
  cp "$HOOK" "$dir/.git/hooks/commit-msg"
  chmod +x "$dir/.git/hooks/commit-msg"
}

design_repo="$TMP/design"
setup_repo "$design_repo"
printf '{"v":2}\n' > "$design_repo/design/figcraft/specs/screen.json"
git -C "$design_repo" add .
if git -C "$design_repo" commit -m 'design: update spec' >/dev/null 2>&1; then
  echo "expected design commit without approval to fail" >&2
  exit 1
fi
git -C "$design_repo" commit -m $'design: update spec\n\nDesign-Approved: Test User, 2026-11-22' >/dev/null

lib_repo="$TMP/lib"
setup_repo "$lib_repo"
mkdir -p "$lib_repo/lib"
echo 'void main() {}' > "$lib_repo/lib/main.dart"
git -C "$lib_repo" add .
git -C "$lib_repo" commit -m 'feat: update app' >/dev/null

echo "commit-msg scenarios passed"
