#!/bin/zsh
# usage: verify.sh <k>  — codex judges before/after screenshots for findings in verify_in_<k>.json
K=$1; REPO=/Users/berloga/Documents/GitHub/flutter_repsync_app; P=$REPO/docs/plans/audit-2026-11-13; R=$REPO/audit/2026-11-13-r1; O=$REPO/audit/2026-11-13-1417
IMGS=(); for f in $(cat $R/audit_set.txt); do IMGS+=(-i $REPO/$f); done
for s in $(python3 -c "import json;print(' '.join(sorted({f['screenshot'] for f in json.load(open('$P/verify_in_$K.json'))})))"); do IMGS+=(-i $O/$s); done
codex exec -m gpt-6.1-terra --sandbox read-only -C $REPO -o $P/verify_out_$K.json "${IMGS[@]}" -- "You verify UX fixes on a real device. Attached images: first the AFTER screenshots listed in audit/2026-11-13-r1/audit_set.txt (in that order; audit/2026-11-13-r1/screens.json says how each was reached, hierarchy/<name>.json has the accessibility tree), then the BEFORE screenshots (from audit/2026-11-13-1417/) of the findings in docs/plans/audit-2026-11-13/verify_in_$K.json (sorted unique 'screenshot' values).
For EACH finding in verify_in_$K.json: find the AFTER screenshot of the same screen/state, and for accessibility-label findings read the matching AFTER hierarchy json. Decide strictly from evidence:
- verified: the problem is visibly/structurally gone in AFTER
- still-open: the same problem is still present in AFTER
- not-covered: no AFTER capture shows that screen/state (do not guess)
Output ONLY a JSON object, no prose: {\"results\": [{\"id\": \"F-0xx\", \"verdict\": \"verified|still-open|not-covered\", \"after\": \"screens/<file>.png or null\", \"reason\": \"one sentence with concrete evidence\"}], \"new_issues\": [{\"screen\": \"...\", \"after\": \"screens/<file>.png\", \"severity\": 1-4, \"evidence\": \"...\"}]}
new_issues: only clear defects visible in AFTER that are NOT in the findings list (layout breakage, clipped/overlapping controls, crashes, blank screens, obviously wrong labels); at most 8; empty list if none. Do not modify files." < /dev/null > $P/verify_$K.log 2>&1
echo "verify $K exit=$? $(wc -c < $P/verify_out_$K.json 2>/dev/null)"
