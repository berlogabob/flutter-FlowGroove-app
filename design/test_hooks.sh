#!/bin/bash
set -euo pipefail

HOOKS="$(cd "$(dirname "$0")/.." && pwd)/.githooks"
HOOK="$HOOKS/commit-msg"
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

# a new spec file is a design change too
new_repo="$TMP/new"
setup_repo "$new_repo"
printf '{"v":1}\n' > "$new_repo/design/figcraft/specs/new_screen.json"
git -C "$new_repo" add .
if git -C "$new_repo" commit -m 'feat: new screen spec' >/dev/null 2>&1; then
  echo "expected new spec without approval to fail" >&2
  exit 1
fi

# parity lock: adding a locked screen tightens (no approval), removing one needs approval
lock_repo="$TMP/lock"
setup_repo "$lock_repo"
printf 'home\n' > "$lock_repo/design/parity_lock.txt"
git -C "$lock_repo" add .
git -C "$lock_repo" commit -m 'chore: lock home' >/dev/null
: > "$lock_repo/design/parity_lock.txt"
git -C "$lock_repo" add .
if git -C "$lock_repo" commit -m 'chore: unlock home' >/dev/null 2>&1; then
  echo "expected parity lock removal without approval to fail" >&2
  exit 1
fi

# pre-commit: a failing design-guard blocks the commit, a passing one does not
fake="$TMP/fakebin"
mkdir -p "$fake"
guard_repo="$TMP/guard"
setup_repo "$guard_repo"
mkdir -p "$guard_repo/lib"
echo 'void main() {}' > "$guard_repo/lib/a.dart"
git -C "$guard_repo" add .
printf '#!/bin/sh\nexit 1\n' > "$fake/make"
chmod +x "$fake/make"
if (cd "$guard_repo" && PATH="$fake:$PATH" "$HOOKS/pre-commit") >/dev/null 2>&1; then
  echo "expected pre-commit to fail when design-guard fails" >&2
  exit 1
fi
printf '#!/bin/sh\nexit 0\n' > "$fake/make"
(cd "$guard_repo" && PATH="$fake:$PATH" "$HOOKS/pre-commit") >/dev/null

echo "hook scenarios passed"
