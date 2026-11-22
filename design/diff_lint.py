"""Find newly added raw design values in lib/ unified diffs."""

import re
import subprocess
from pathlib import Path

_RAW_PATTERNS = (
    re.compile(r"fontSize:\s*\d"),
    re.compile(r"\bTextStyle\("),
    re.compile(r"EdgeInsets\.(?:all|symmetric|only|fromLTRB)\([^)]*\b\d+(?:\.\d+)?\b"),
    re.compile(r"SizedBox\((?:width|height):\s*\d"),
    re.compile(r"(?:BorderRadius\.circular|Radius\.circular)\(\s*\d"),
    re.compile(r"\bColors\.(?!transparent\b)[a-z]\w*"),
    re.compile(r"Color\(0x"),
)


def _skipped(path: str) -> bool:
    relative = path.removeprefix("lib/")
    return path.endswith((".g.dart", ".freezed.dart")) or relative.startswith("theme/") or Path(path).name == "pdf_service.dart"


def bad_lines(diff: str) -> list[str]:
    """Return file, new line number and source for each forbidden added line."""
    hits = []
    path = None
    line_number = 0
    in_lib = False
    skip = False
    for line in diff.splitlines():
        if line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else None
            in_lib = bool(path and path.startswith("lib/"))
            skip = bool(path and _skipped(path))
            continue
        if line.startswith("@@"):
            match = re.search(r"\+(\d+)(?:,\d+)?", line)
            if match:
                line_number = int(match.group(1))
            continue
        if line.startswith("+") and not line.startswith("+++"):
            content = line[1:]
            if in_lib and not skip and "// ds-allow:" not in content and any(pattern.search(content) for pattern in _RAW_PATTERNS):
                hits.append(f"{path}:{line_number}: {content}")
            line_number += 1
        elif line.startswith("-") and not line.startswith("---"):
            continue
        elif line and not line.startswith(("\\", "diff ", "index ", "--- ")) and line_number:
            line_number += 1
    return hits


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    if subprocess.run(["git", "rev-parse", "--verify", "HEAD~1"], cwd=repo, capture_output=True).returncode == 0 and __import__("os").environ.get("CI"):
        command = ["git", "diff", "--no-ext-diff", "--unified=0", "HEAD~1..HEAD", "--", "lib/"]
    else:
        command = ["git", "diff", "--cached", "--no-ext-diff", "--unified=0", "--", "lib/"]
    result = subprocess.run(command, cwd=repo, text=True, capture_output=True, check=True)
    messages = bad_lines(result.stdout)
    for message in messages:
        print(message)
    return 1 if messages else 0


if __name__ == "__main__":
    raise SystemExit(main())
