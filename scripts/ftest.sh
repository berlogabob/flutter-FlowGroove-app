#!/usr/bin/env bash
# flutter test with a short failure report: prints only the failing lines (for runner verify tails).
# Usage: scripts/ftest.sh <flutter test args...>
log=$(mktemp -t ftest)
if flutter test "$@" >"$log" 2>&1; then
  tail -1 "$log"
  rm -f "$log"
  exit 0
fi
# Drop log noise (analytics/auth fallbacks, progress lines) so the failures fit the runner's 2500-char tail.
grep -vE 'Analytics Error|FirebaseAuth is unavailable|^[0-9]+:[0-9]+ \+[0-9]+' "$log" \
  | grep -E 'Expected|EXCEPTION|Error|Failed|══' -A14 | head -60
tail -1 "$log"
rm -f "$log"
exit 1
