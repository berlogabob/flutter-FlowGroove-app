#!/bin/bash
# usage: gen.sh <key>   -- one screen spec via codex; logs in logs/<key>.log
set -u
cd "$(dirname "$0")/../.."
D=design/figcraft
IFS=$'\t' read -r key page src name < <(awk -F"\t" -v k="$1" '$1==k' $D/screens.tsv)
slot=$(awk -F'\t' -v p="$page" -v k="$key" '$2==p{if($1==k){print n; exit} n++}' $D/screens.tsv)
[ "$page" = "Songs" ] && slot=$((slot+1))   # slot 0 = songs_list
mkdir -p $D/logs
codex exec -s workspace-write -m gpt-6.1-terra -C "$PWD" -o $D/logs/$key.final "Write ONE file: $D/specs/$key.json, a screen spec that recreates the Flutter screen $src as a FigCraft design.
Read $D/SPEC.md first (format, node types, tokens, rules) and $D/specs/songs_list.json (worked example).
Then read $src and the widgets it builds from (lib/widgets/..., lib/screens/main_shell.dart for shell bars) to get the real layout, labels, icons and controls.
Use exactly: \"name\": \"$name\", \"page\": \"$page\", \"source\": \"$src\", \"slot\": $slot.
Validate with: python3 $D/build.py check $D/specs/$key.json  -- fix until it prints ok.
Do not edit any other file. Do not run git. Print DONE when the check passes." < /dev/null > $D/logs/$key.log 2>&1
python3 $D/build.py check $D/specs/$key.json
