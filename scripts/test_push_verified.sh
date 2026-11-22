#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export LOG="$tmp/log" WATCH_STATUS=0 RERUN_WAIT=0
sha=0123456789012345678901234567890123456789
export SHA="$sha"
mkdir "$tmp/bin"
cat > "$tmp/bin/git" <<'FAKE'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >> "$LOG"
if [[ $1 == rev-parse ]]; then
  if [[ ${2:-} == --abbrev-ref ]]; then echo second01; else echo "$SHA"; fi
fi
FAKE
cat > "$tmp/bin/gh" <<'FAKE'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >> "$LOG"
if [[ "$1 $2" == 'run list' ]]; then
  printf '[{"databaseId":42,"headSha":"%s"}]\n' "$SHA"
elif [[ "$1 $2" == 'run watch' ]]; then
  exit "$WATCH_STATUS"
fi
FAKE
chmod +x "$tmp/bin/git" "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH"

bash "$root/scripts/push_verified.sh" HEAD second01
sed -n '/^git push /p' "$LOG" > "$tmp/pushes"
[[ $(wc -l < "$tmp/pushes") -eq 3 ]]
sed -n '1p' "$tmp/pushes" | grep -Eq "^git push origin $sha:refs/heads/codex/release-[0-9]{8}-[0-9]{6}$"
sed -n '2p' "$tmp/pushes" | grep -Fx "git push origin $sha:refs/heads/second01"
temp_ref=$(sed -n '1s/.*:refs\/heads\///p' "$tmp/pushes")
sed -n '3p' "$tmp/pushes" | grep -Fx "git push origin --delete $temp_ref"
grep -Fx 'gh run watch 42 --exit-status --interval 60' "$LOG"

: > "$LOG"
export WATCH_STATUS=1
if bash "$root/scripts/push_verified.sh" HEAD second01 > "$tmp/red-output" 2>&1; then
  echo 'Expected a failed CI run to reject the release push' >&2
  exit 1
fi
grep -q '42' "$tmp/red-output"
grep -Fx 'gh run rerun 42 --failed' "$LOG"  # one retry for the emulator flake (FINDINGS F19)
if grep -F "git push origin $sha:refs/heads/second01" "$LOG" || grep -F 'git push origin --delete' "$LOG"; then
  echo 'Failed CI must keep the temporary branch and not push the release branch' >&2
  exit 1
fi
