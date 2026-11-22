"""Reject changes that loosen design and test guardrails."""

import json
import subprocess
from pathlib import Path


def _numbers(value, prefix=""):
    if isinstance(value, dict):
        for key, item in value.items():
            yield from _numbers(item, f"{prefix}.{key}" if prefix else key)
    elif isinstance(value, (int, float)) and not isinstance(value, bool):
        yield prefix, value


def _expectations(content):
    import re

    return len(re.findall(r"\b(?:expect|expectLater)\s*\(", content))


def violations(head: dict[str, str], work: dict[str, str]) -> list[str]:
    """Return messages for changes that weaken the supplied HEAD baseline."""
    messages = []
    ratchet = "design/ratchets.json"
    if ratchet in head and ratchet in work:
        try:
            old = dict(_numbers(json.loads(head[ratchet])))
            new = dict(_numbers(json.loads(work[ratchet])))
            for key, value in new.items():
                if key in old and value > old[key]:
                    messages.append(f"{ratchet}: {key} increased from {old[key]} to {value}")
        except (json.JSONDecodeError, TypeError):
            messages.append(f"{ratchet}: could not compare JSON values")

    parity = "design/parity_lock.txt"
    if parity in head and parity in work:
        removed = set(head[parity].splitlines()) - set(work[parity].splitlines())
        messages.extend(f"{parity}: removed locked line: {line}" for line in sorted(removed))

    allow = "design/stable_layout_allow.txt"
    if allow in head and allow in work:
        added = set(work[allow].splitlines()) - set(head[allow].splitlines())
        messages.extend(f"{allow}: added allowance: {line}" for line in sorted(added))

    for path in sorted(set(head) | set(work)):
        if path.startswith("test/") and path.endswith("_test.dart") and path in head and path in work:
            before, after = _expectations(head[path]), _expectations(work[path])
            if after < before:
                messages.append(f"{path}: expect count decreased from {before} to {after}")
    return messages


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    paths = ["design/ratchets.json", "design/parity_lock.txt", "design/stable_layout_allow.txt"]
    changed = subprocess.run(["git", "diff", "--name-only", "HEAD"], cwd=repo, text=True, capture_output=True, check=True).stdout.splitlines()
    paths.extend(path for path in changed if path.startswith("test/") and path.endswith("_test.dart"))
    head, work = {}, {}
    for path in paths:
        result = subprocess.run(["git", "show", f"HEAD:{path}"], cwd=repo, text=True, capture_output=True)
        if result.returncode == 0:
            head[path] = result.stdout
        file_path = repo / path
        if file_path.is_file():
            work[path] = file_path.read_text(encoding="utf-8")
    messages = violations(head, work)
    for message in messages:
        print(message)
    return 1 if messages else 0


if __name__ == "__main__":
    raise SystemExit(main())
