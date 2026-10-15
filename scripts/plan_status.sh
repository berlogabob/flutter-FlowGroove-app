#!/usr/bin/env bash
# Trace helper: where is the audit-r3 run? Usage: scripts/plan_status.sh [worktree path]
WT="${1:-/Users/berloga/Documents/GitHub/flutter_repsync_ar3}"; P="$WT/docs/plans/audit-r3"
pgrep -fl plan_run_pi >/dev/null && echo "RUNNER: alive" || echo "RUNNER: not running"
cat "$P/STATUS.md" 2>/dev/null
echo "--- last ledger lines"; tail -n 5 "$P/ledger.jsonl" 2>/dev/null | cut -c1-260
echo "--- last commits"; git -C "$WT" log --oneline -n 5
