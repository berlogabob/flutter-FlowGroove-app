"""Merge build/check/<platform>.json into one table and build/check/report.md.

Usage: uv run python scripts/check_compare.py
"""

import json
from pathlib import Path

DIR = Path(__file__).resolve().parent.parent / "build" / "check"
LABEL = {"pass": "pass", "fail": "FAIL", "skip": "skip"}


def main():
    runs = {}
    for f in sorted(DIR.glob("*.json")):
        runs[f.stem] = {r["id"]: r for r in json.loads(f.read_text())}
    if not runs:
        raise SystemExit(f"no results in {DIR}")
    platforms = list(runs)
    ids = sorted({i for r in runs.values() for i in r})
    titles = {i: r[i]["title"] for r in runs.values() for i in r}

    def cell(p, i):
        r = runs[p].get(i)
        return LABEL[r["status"]] if r else "missing"

    def row(i):
        return [cell(p, i) for p in platforms]

    # Rows where platforms disagree or anything is not a plain pass come first.
    ids.sort(key=lambda i: (set(row(i)) == {"pass"}, i))
    header = ["ID", "Title", *platforms]
    rows = [[i, titles[i], *row(i)] for i in ids]
    widths = [max(len(str(x[c])) for x in [header, *rows]) for c in range(len(header))]
    lines = ["  ".join(str(x[c]).ljust(widths[c]) for c in range(len(header))).rstrip()
             for x in [header, *rows]]
    print("\n".join(lines))

    md = ["# Check report", "", "| " + " | ".join(header) + " |",
          "|" + "|".join("---" for _ in header) + "|"]
    md += ["| " + " | ".join(map(str, r)) + " |" for r in rows]
    problems = [(i, p, runs[p][i]) for i in ids for p in platforms
                if i in runs[p] and runs[p][i]["status"] != "pass"]
    if problems:
        md += ["", "## Details", ""]
        md += [f"- {i} on {p}: {r['status']} - {r['message']}" for i, p, r in problems]
    (DIR / "report.md").write_text("\n".join(md) + "\n")
    if problems:
        print()
        for i, p, r in problems:
            print(f"{i} {p}: {r['status']} - {r['message']}")


if __name__ == "__main__":
    main()
