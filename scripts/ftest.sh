#!/usr/bin/env bash
# flutter test with a short failure report: prints only the failing lines (for runner verify tails).
# Usage: scripts/ftest.sh <flutter test args...>
log=$(mktemp -t ftest)
if flutter test "$@" >"$log" 2>&1; then
  tail -1 "$log"
  rm -f "$log"
  exit 0
fi
grep -E 'Expected|EXCEPTION|Error|Failed|══' -A14 "$log" | head -80
tail -1 "$log"
rm -f "$log"
exit 1
