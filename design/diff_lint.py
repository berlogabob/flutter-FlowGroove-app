"""Find newly added raw design values in lib/ unified diffs."""

import re
import subprocess
import sys
from pathlib import Path

ALLOW = re.compile(r"//\s*ds-allow:\s*\S.{2,}")

_RAW_PATTERNS = (
    re.compile(r"fontSize:\s*\d"),
    re.compile(r"\bTextStyle\("),
    re.compile(r"EdgeInsets\.(?:all|symmetric|only|fromLTRB)\([^)]*\b\d+(?:\.\d+)?\b"),
    re.compile(r"EdgeInsetsDirectional\.\w+\([^)]*\b\d"),
    re.compile(r"SizedBox(?:\.square)?\([^)]*\b(?:width|height|dimension):\s*\.?\d"),
    re.compile(r"(?:BorderRadius\.circular|Radius\.circular)\(\s*\d"),
    re.compile(r"\bColors\.(?!transparent\b)[a-z]\w*"),
    re.compile(r"Color\(\s*0x"),
    re.compile(r"Color\.from(?:ARGB|RGBO)\("),
)


def _skipped(path: str) -> bool:
    relative = path.removeprefix("lib/")
    return path.endswith((".g.dart", ".freezed.dart")) or relative.startswith("theme/") or path == "lib/services/export/pdf_service.dart"


def bad_lines(diff: str) -> list[str]:
    """Return file, new line number and source for each forbidden added line."""
    hits = []
    path = None
    line_number = 0
    added = []

    def flush():
        if not added or not path or not path.startswith("lib/") or _skipped(path):
            added.clear()
            return
        source = "\n".join(line for _, line in added)
        found = set()
        for pattern in _RAW_PATTERNS:
            for match in pattern.finditer(source):
                start = source.count("\n", 0, match.start())
                end = source.count("\n", 0, match.end())
                if not any(ALLOW.search(line) for _, line in added[start:end + 1]):
                    found.add(start)
        hits.extend(f"{path}:{added[i][0]}: {added[i][1]}" for i in sorted(found))
        added.clear()

    for line in diff.splitlines():
        if line.startswith("+++ "):
            flush()
            path = line[6:] if line.startswith("+++ b/") else None
        elif line.startswith("@@"):
            flush()
            match = re.search(r"\+(\d+)(?:,\d+)?", line)
            if match:
                line_number = int(match.group(1))
        elif line.startswith("+") and not line.startswith("+++"):
            added.append((line_number, line[1:]))
            line_number += 1
        elif line.startswith("-") and not line.startswith("---"):
            continue
        else:
            if line and not line.startswith(("\\", "diff ", "index ", "--- ")) and line_number:
                line_number += 1
    flush()
    return hits


def main(argv=None, repo=None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    repo = Path(repo or Path(__file__).resolve().parent.parent)
    git = ["git", "-c", "core.quotePath=false"]
    if argv:
        if len(argv) != 2 or argv[0] != "--base":
            raise SystemExit("usage: diff_lint.py [--base <ref>]")
        if subprocess.run(git + ["rev-parse", "--verify", "--quiet", argv[1] + "^{commit}"], cwd=repo, capture_output=True).returncode:
            print(f"diff_lint: cannot resolve --base {argv[1]}")
            return 2
        command = git + ["diff", "--no-ext-diff", "--unified=0", f"{argv[1]}...HEAD", "--", "lib/"]
    else:
        has_head = subprocess.run(git + ["rev-parse", "--verify", "HEAD"], cwd=repo, capture_output=True).returncode == 0
        command = git + ["diff", "HEAD", "--no-ext-diff", "--unified=0", "--", "lib/"] if has_head else None
    if command is None:
        diff = ""
    else:
        result = subprocess.run(command, cwd=repo, text=True, capture_output=True, check=True)
        diff = result.stdout
    if not argv:
        untracked = subprocess.run(
            git + ["ls-files", "-z", "--others", "--exclude-standard", "--", "lib/"],
            cwd=repo, text=True, capture_output=True, check=True,
        ).stdout.split("\0")
        for path in untracked:
            if not path or not (repo / path).is_file() or (repo / path).is_symlink():
                continue
            content = (repo / path).read_text(errors="replace").splitlines()
            diff += f"\n+++ b/{path}\n@@ -0,0 +1,{len(content)} @@\n" + "".join(f"+{line}\n" for line in content)
    messages = bad_lines(diff)
    for message in messages:
        print(message)
    return 1 if messages else 0


if __name__ == "__main__":
    raise SystemExit(main())
