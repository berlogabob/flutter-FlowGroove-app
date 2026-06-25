#!/usr/bin/env bash
# Append new history: print ready-to-paste YAML stubs for commits since the last recorded one.
#
# Workflow after a release:
#   1. Find the last commit hash already in site/data/history.yaml (the newest `commits: [...]`).
#   2. scripts/history-skeleton.sh <that-hash>   # prints stubs for everything newer
#   3. Paste the stubs into the `changes:` list, fill `why`/`docs_impact`/`blog`.
#   4. python3 scripts/gen_history.py --changelog # re-render the wiki page.
#
# Or just regenerate the whole file (curated `why`/`blog` live in gen_history.py, so it's safe):
#   python3 scripts/gen_history.py && python3 scripts/gen_history.py --changelog
#
# The `Release x.y.z+N` auto-deploy churn is filtered out automatically.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ $# -lt 1 ]; then
  echo "usage: $0 <last-recorded-commit-hash>" >&2
  exit 1
fi
python3 scripts/gen_history.py --since "$1"
