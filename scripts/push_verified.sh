#!/usr/bin/env bash
set -euo pipefail

sha=$(git rev-parse "${1:-HEAD}")
branch=${2:-$(git rev-parse --abbrev-ref HEAD)}
tmp="codex/release-$(date +%Y%m%d-%H%M%S)"
git push origin "$sha:refs/heads/$tmp"

run_id=''
for ((attempt = 0; attempt < 30; attempt++)); do
  runs=$(gh run list --branch "$tmp" --workflow checks.yml --json databaseId,headSha)
  run_id=$(printf '%s' "$runs" | python3 -c 'import json, sys; sha = sys.argv[1]; print(next((str(r["databaseId"]) for r in json.load(sys.stdin) if r["headSha"] == sha), ""))' "$sha")
  if [[ -n $run_id ]]; then break; fi
  sleep 10
done
if [[ -z $run_id ]]; then
  echo "No checks.yml run found for $sha on $tmp after 5 minutes" >&2
  exit 1
fi
if ! gh run watch "$run_id" --exit-status --interval 60; then
  # one retry: the emulator job sometimes loses its device (FINDINGS F19); a real failure fails again
  echo "CI run $run_id failed; rerunning its failed jobs once" >&2
  gh run rerun "$run_id" --failed
  sleep "${RERUN_WAIT:-20}"
  if ! gh run watch "$run_id" --exit-status --interval 60; then
    echo "CI run $run_id failed; keeping $tmp" >&2
    exit 1
  fi
fi
git push origin "$sha:refs/heads/$branch"
git push origin --delete "$tmp"
