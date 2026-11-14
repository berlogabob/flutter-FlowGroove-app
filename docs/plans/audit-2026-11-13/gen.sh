#!/bin/zsh
# usage: gen.sh <problem-id> [extra decision text]   — one read-only codex call -> gen/<id>.json
ID=$1; EXTRA=$2; IMGARG=$3; REPO=/Users/berloga/Documents/GitHub/flutter_repsync_app; WT=$REPO/../flutter_repsync_a1113; P=$REPO/docs/plans/audit-2026-11-13; A=$REPO/audit/2026-11-13-1417
DESC=$(python3 - "$ID" <<'PY'
import json,sys,re
i=sys.argv[1]; R="/Users/berloga/Documents/GitHub/flutter_repsync_app/"
for f in json.load(open(R+"audit/2026-11-13-1417/findings.json"))["findings"]:
    if f["id"]==i: print(json.dumps({k:f[k] for k in ("id","criterion","screen","severity","evidence","recommendation","screenshot")},ensure_ascii=False)); sys.exit()
for l in open(R+"docs/plans/audit-2026-11-13/PROBLEMS.md"):
    if l.startswith("| "+i+" "): print(l.strip()+" "); sys.exit()
PY
)
IMG=(); S=$(print -r -- "$DESC" | python3 -c "import json,sys
try: print(json.loads(sys.stdin.read())['screenshot'])
except Exception: pass"); [ -n "$S" ] && [ -f $A/$S ] && IMG=(-i $A/$S); [ -n "$IMGARG" ] && [ -f "$IMGARG" ] && IMG=(-i $IMGARG)
codex exec -m gpt-6.1-terra --sandbox read-only -C $WT -o $P/gen/$ID.json "${IMG[@]}" -- "You are planning fixes for a Flutter app (repo root = cwd). A much weaker local model will execute each task, so tasks must be tiny and fully explicit.
PROBLEM: $DESC
$EXTRA
Locate the responsible code (rg, read files). Then output ONLY a JSON array (no prose, no code fence) of 1-6 tasks that together fix the problem with the smallest possible change:
{\"id\": \"$ID-a\" (then -b, -c...), \"finding\": \"$ID\", \"executor\": \"pi\", \"title\": \"<max 8 words>\", \"files\": [\"<exactly ONE repo-relative existing file>\"], \"prompt\": \"...\", \"verify\": \"...\", \"after\": [ids of earlier tasks this one needs], \"status\": \"pending\"}
Rules:
- One file per task, one logical change per task. Reuse existing widgets/helpers/theme tokens (lib/theme/mono_pulse_theme.dart); no new dependencies, no new files unless unavoidable.
- prompt: self-contained; name the file, quote the exact existing lines to change (verbatim, enough to be unique) and give the exact replacement code. End with: 'Edit only the listed file; change nothing else; no refactors. When done print DONE.'
- verify: a bash one-liner run from repo root that fails before the change and passes after: rg -q checks for the new code (use rg -F for literals) && dart analyze <file>. Add 'flutter test <existing test file>' only if a directly relevant test exists. Do not use single quotes inside double-quoted JSON incorrectly; the value must be valid JSON.
- Do not change behaviour outside the problem. Do not touch tests unless the change breaks an existing assertion (then add a separate task for that test file).
- If the problem cannot be fixed safely without a product decision or is not reproducible from code, output [] and nothing else.
Do not modify any file." < /dev/null > $P/gen/$ID.log 2>&1
echo "$ID exit=$? $(wc -c < $P/gen/$ID.json 2>/dev/null)"
