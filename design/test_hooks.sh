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

# A Makefile-only commit must run the guard too.
make_repo="$TMP/make-only"
setup_repo "$make_repo"
cp "$HOOKS/pre-commit" "$make_repo/.git/hooks/pre-commit"
chmod +x "$make_repo/.git/hooks/pre-commit"
echo 'all:' > "$make_repo/Makefile"
git -C "$make_repo" add Makefile
printf '#!/bin/sh\nexit 1\n' > "$fake/make"
if (cd "$make_repo" && PATH="$fake:$PATH" git commit -qm 'test: makefile'); then
  echo "expected Makefile-only commit to fail when design-guard fails" >&2
  exit 1
fi

# A runner must reject and undo commits made by an executor.
python3 - "$HOOKS/../scripts/plan_run.py" "$TMP" <<'PYTEST'
import importlib.util, json, pathlib, sys
from unittest.mock import patch
spec = importlib.util.spec_from_file_location("plan_run", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
root = pathlib.Path(sys.argv[2]) / "plan"
root.mkdir()
(root / "tasks.json").write_text(json.dumps({"tasks": [{"id": "G10", "executor": "codex", "title": "guard", "finding": "test", "files": [], "verify": "", "suite": False}]}))
m.PLAN = root
m.LEDGER = root / "ledger.jsonl"
commands = []
heads = iter(["start", "moved"])
def sh(cmd, **kwargs):
    commands.append(cmd)
    if "rev-parse HEAD" in cmd:
        return 0, next(heads)
    return 0, ""
m.sh = sh
m.rollback = lambda: commands.append("rollback")
m.run_exec = lambda ex, task: (0, "")
m.verify = lambda task: (True, "")
with patch.object(sys, "argv", ["plan_run.py", "--only=G10"]):
    m.main()
record = json.loads(m.LEDGER.read_text())
assert record["verdict"] == "fail", record
assert record["verify_tail"] == "executor moved HEAD", record
assert any("git reset -q --hard start" in cmd for cmd in commands), commands
PYTEST

echo "hook scenarios passed"
