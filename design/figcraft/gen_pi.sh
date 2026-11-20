#!/bin/bash
# usage: gen_pi.sh <key>  -- one spec via pi + Ornith 35b (Studio); row from overlays.tsv or variants.tsv
set -u
cd "$(dirname "$0")/../.."
D=design/figcraft
row=$(awk -F'\t' -v k="$1" '$1==k' $D/overlays.tsv $D/variants.tsv | head -1)
[ -z "$row" ] && { echo "no row $1"; exit 2; }
IFS=$'\t' read -r key page src name extra <<< "$row"
slot=$(python3 - "$page" "$key" <<'PY'
import json, glob, sys
page, key = sys.argv[1], sys.argv[2]
used = []
for p in glob.glob('design/figcraft/specs/*.json'):
    if p.endswith(f'/{key}.json'): continue
    s = json.load(open(p))
    if s.get('page') == page: used.append(s.get('slot', 0))
print(max(used, default=-1) + 1)
PY
)
file=${src%%:*}
if [ "$page" = "Sheets & Dialogs" ]; then
  what="the $extra opened at $src (read the code around that line: the showModalBottomSheet or showDialog builder and the widget it shows). Use \"modal\": \"$extra\" and follow the 'Sheets and dialogs' section of SPEC.md; examples are in $D/examples/."
  ctx="$D/examples/modal_dialog.json $D/examples/modal_sheet.json"
else
  what="$extra, from $src. Base it on the existing spec $D/specs/$(basename ${file%_screen.dart}).json if it exists, changing only what differs in this state."
  ctx=""
fi
mkdir -p $D/logs
PI_VERIFY="python3 $D/build.py check $D/specs/$key.json" PI_MAX_ITERS=3 PI_CHECKPOINT=0 PI_TIMEOUT=360 \
  ~/.claude/skills/pi-delegate/scripts/pi-run.sh "Create exactly one new file: $D/specs/$key.json. It is a JSON screen spec (format in $D/SPEC.md) recreating $what
Read $file for the real labels, icons, controls and layout; use realistic sample data for a band app.
Use exactly: \"name\": \"$name\", \"page\": \"$page\", \"source\": \"$src\", \"slot\": $slot.
Only node types, tokens, text styles and Flutter Icons names listed in SPEC.md. Write valid JSON (no comments). Do not touch any other file." \
  $D/SPEC.md $D/specs/songs_list.json $ctx $file > $D/logs/pi_$key.log 2>&1
python3 $D/build.py check $D/specs/$key.json
