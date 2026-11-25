#!/usr/bin/env bash
# Run the checks one area per app start and merge the results into build/check/<platform>.json.
# Use when one long run is unstable (web): scripts/check_run_areas.sh <android|ios|web> [device-id]
set -uo pipefail
PLATFORM="${1:?usage: check_run_areas.sh <android|ios|web> [device-id]}"
cd "$(dirname "$0")/.."
mkdir -p build/check/parts
rm -f build/check/parts/"$PLATFORM"-*.json
for area in ${CHECK_AREAS:-AU SG SL BD EV MT SM RC MD ST}; do
  CHECK_ONLY="$area" CHECK_MAX_MIN="${CHECK_MAX_MIN:-15}" ./scripts/check_run.sh "$@" >"build/check/parts/$PLATFORM-$area.log" 2>&1
  [ -f "build/check/$PLATFORM.json" ] && mv "build/check/$PLATFORM.json" "build/check/parts/$PLATFORM-$area.json" || echo "$area: no result file" >&2
done
uv run python - "$PLATFORM" <<'PY'
import glob, json, sys
rows = {}
for path in sorted(glob.glob(f"build/check/parts/{sys.argv[1]}-*.json")):
    for row in json.load(open(path)):
        rows[row["id"]] = row  # an area run wins over the sign-in repeated by other areas
json.dump(list(rows.values()), open(f"build/check/{sys.argv[1]}.json", "w"), indent=1)
print(f"merged {len(rows)} checks")
PY
