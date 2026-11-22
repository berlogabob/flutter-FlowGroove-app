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


def _code_only(content):
    import re

    return re.sub(r"//[^\n]*", "", re.sub(r"/\*.*?\*/", "", content, flags=re.S))


def _expectations(content):
    import re

    return len(re.findall(r"\b(?:expect|expectLater)\s*\(", _code_only(content)))


def _skips(content):
    import re

    return len(re.findall(r"\bskip\s*:|@Skip\s*\(|\bmarkTestSkipped\s*\(", _code_only(content)))


def _code_of(test_path):
    return "lib/" + test_path[len("test/"):-len("_test.dart")] + ".dart"


def violations(head: dict[str, str], work: dict[str, str]) -> list[str]:
    """Return messages for changes that weaken the supplied HEAD baseline."""
    messages = []
    ratchet = "design/ratchets.json"
    if ratchet in head and ratchet not in work:
        messages.append(f"{ratchet}: deleted")
    elif ratchet in head:
        try:
            old = dict(_numbers(json.loads(head[ratchet])))
            new = dict(_numbers(json.loads(work[ratchet])))
            for key, value in old.items():
                if key not in new:
                    messages.append(f"{ratchet}: {key} removed or no longer a number")
                elif new[key] > value:
                    messages.append(f"{ratchet}: {key} increased from {value} to {new[key]}")
        except (json.JSONDecodeError, TypeError):
            messages.append(f"{ratchet}: could not compare JSON values")

    parity = "design/parity_lock.txt"
    if parity in head:  # a deleted lock file removes every locked line
        removed = set(head[parity].splitlines()) - set(work.get(parity, "").splitlines())
        messages.extend(f"{parity}: removed locked line: {line}" for line in sorted(removed))

    allow = "design/stable_layout_allow.txt"
    if allow in head and allow in work:
        added = set(work[allow].splitlines()) - set(head[allow].splitlines())
        messages.extend(f"{allow}: added allowance: {line}" for line in sorted(added))

    for path in sorted(set(head) | set(work)):
        if not (path.startswith("test/") and path.endswith("_test.dart") and path in head):
            continue
        if path not in work:
            code = _code_of(path)
            if not (code in head and code not in work):  # a test may go only together with its code
                messages.append(f"{path}: test file deleted (allowed only together with {code})")
            continue
        before, after = _expectations(head[path]), _expectations(work[path])
        if after < before:
            messages.append(f"{path}: expect count decreased from {before} to {after}")
        if _skips(work[path]) > _skips(head[path]):
            messages.append(f"{path}: skip added")
    return messages


def main(argv=None, repo=None) -> int:
    """Local: working tree vs HEAD. CI: `--base <ref>` compares HEAD with its merge-base with <ref>;
    a `Design-Approved:` line in a pushed commit message lets an approved change through."""
    import sys

    argv = sys.argv[1:] if argv is None else argv
    repo = Path(repo) if repo else Path(__file__).resolve().parent.parent

    def git(*args):
        return subprocess.run(["git", *args], cwd=repo, text=True, capture_output=True)

    base = argv[argv.index("--base") + 1] if "--base" in argv else None
    if base:
        merge_base = git("merge-base", base, "HEAD")
        old = merge_base.stdout.strip()
        if merge_base.returncode != 0 or not old:
            print(f"gate_guard: cannot resolve --base {base} (fetch-depth 0?): {merge_base.stderr.strip()}")
            return 2
        changed = git("diff", "--name-only", "--no-renames", f"{old}..HEAD").stdout.splitlines()

        def read_work(path):
            result = git("show", f"HEAD:{path}")
            return result.stdout if result.returncode == 0 else None
    else:
        old = "HEAD"
        changed = git("diff", "--name-only", "--no-renames", "HEAD").stdout.splitlines()

        def read_work(path):
            file_path = repo / path
            return file_path.read_text(encoding="utf-8") if file_path.is_file() else None

    paths = ["design/ratchets.json", "design/parity_lock.txt", "design/stable_layout_allow.txt"]
    tests = [path for path in changed if path.startswith("test/") and path.endswith("_test.dart")]
    paths += tests + [_code_of(path) for path in tests]
    head, work = {}, {}
    for path in paths:
        result = git("show", f"{old}:{path}")
        if result.returncode == 0:
            head[path] = result.stdout
        content = read_work(path)
        if content is not None:
            work[path] = content
    messages = violations(head, work)
    for message in messages:
        print(message)
    import re

    if messages and base and re.search(r"^Design-Approved: .+", git("log", "--format=%B", f"{old}..HEAD").stdout, re.M):
        print("Design-Approved in the pushed commits: not blocking")
        return 0
    return 1 if messages else 0

if __name__ == "__main__":
    raise SystemExit(main())
