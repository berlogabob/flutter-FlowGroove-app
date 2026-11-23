"""Helpers for comparing static design labels with Dart source literals."""

import re
import json
import sys
from pathlib import Path

try:
    from spec_tree import flatten
except ImportError:  # Imported as part of the design.figcraft package.
    from design.figcraft.spec_tree import flatten


_DART_STRING = re.compile(r"(['\"])((?:\\.|(?!\1).)*?)\1", re.DOTALL)


def lib_literals(lib_dir: str) -> set[str]:
    """Return non-interpolated, quoted string literals found under ``lib_dir``."""
    literals = set()
    for dart_file in Path(lib_dir).rglob("*.dart"):
        source = dart_file.read_text(encoding="utf-8")
        for match in _DART_STRING.finditer(source):
            value = match.group(2).strip()
            if "$" not in value:
                literals.add(value)
    return literals


def static(texts: list[str], literals: set[str]) -> list[str]:
    """Keep text entries that occur as static source literals, preserving order."""
    return [text for text in texts if text in literals]


MIN_LABELS = 2
KIND_ALIASES = {"switchrow": "switch"}


def compare(spec_flat: dict, dump: dict, literals: set[str]) -> dict:
    """Compare flattened spec labels and kinds with a rendered dump."""
    def labels(items):
        return [item if isinstance(item, str) else item.get("v", "")
                for item in items]

    spec_labels = [label for label in labels(spec_flat.get("texts", []))
                   if label in literals]
    dump_labels = [label for label in labels(dump.get("texts", []))
                   if label in literals]
    spec_set, dump_set = set(spec_labels), set(dump_labels)
    missing = sorted(spec_set - dump_set)
    extra = [] if "modal" in spec_flat else sorted(dump_set - spec_set)

    def kind_set(items):
        # flatten() yields strings, tree dumps yield {"kind": ...}.
        kinds = {item if isinstance(item, str) else item.get("kind") for item in items} - {None, ""}
        # A spec switchrow is a Switch in a row in code (private _SwitchRow widgets): same kind.
        return {KIND_ALIASES.get(kind, kind) for kind in kinds}

    spec_kinds = kind_set(spec_flat.get("kinds", []))
    dump_kinds = kind_set(dump.get("kinds", []))
    kinds_missing = sorted(spec_kinds - dump_kinds)
    kinds_extra = [] if "modal" in spec_flat else sorted(dump_kinds - spec_kinds)

    common = spec_set & dump_set
    spec_order = list(dict.fromkeys(label for label in spec_labels if label in common))
    dump_order = list(dict.fromkeys(label for label in dump_labels if label in common))
    # LCS preserves the first occurrence order while tolerating unrelated labels.
    previous = [0] * (len(dump_order) + 1)
    for left in spec_order:
        current = [0]
        for index, right in enumerate(dump_order, 1):
            current.append(previous[index - 1] + 1 if left == right
                           else max(previous[index], current[-1]))
        previous = current
    order = previous[-1] / len(common) if common else 1.0

    # Fewer than 2 shared static labels proves nothing about the screen: never a pass, never locked.
    weak = len(common) < MIN_LABELS
    passed = not (missing or extra or kinds_missing or kinds_extra) and order == 1.0 and not weak
    return {
        "pass": passed,
        "weak": weak,
        "missing": missing,
        "extra": extra,
        "kinds_missing": kinds_missing,
        "kinds_extra": kinds_extra,
        "order": order,
    }


def main(argv: list[str] | None = None) -> int:
    """Compare default render dumps against specs, enforcing the parity lock."""
    argv = list(sys.argv[1:] if argv is None else argv)
    lock_passing = "--lock-passing" in argv
    if any(arg != "--lock-passing" for arg in argv):
        print("usage: parity_check.py [--lock-passing]", file=sys.stderr)
        return 2

    root = Path.cwd()
    design = root / "design"
    keys = [line.strip() for line in (design / "render_keys.txt").read_text(encoding="utf-8").splitlines()
            if line.strip()]
    lock_path = design / "parity_lock.txt"
    locked = {line.strip() for line in lock_path.read_text(encoding="utf-8").splitlines()
              if line.strip()} if lock_path.exists() else set()
    literals = lib_literals(str(root / "lib"))
    icons_path = root / "design/figcraft/icons.txt"
    icons = {line.strip() for line in icons_path.read_text(encoding="utf-8").splitlines()
             if line.strip()} if icons_path.exists() else set()

    results = {}
    rendered = passed = locked_failing = 0
    passing_keys = []
    for key in keys:
        spec_path = root / "design/figcraft/specs" / f"{key}.json"
        spec = json.loads(spec_path.read_text(encoding="utf-8"))
        theme = spec.get("mode", "dark")
        dump_path = root / "design/render" / f"{key}@{theme}-412-1.00.json"
        spec_flat = flatten(spec, icons)
        if dump_path.exists():
            rendered += 1
            result = compare(spec_flat, json.loads(dump_path.read_text(encoding="utf-8")), literals)
        else:
            result = {"pass": False, "missing_dump": True, "missing": [], "extra": [],
                      "kinds_missing": [], "kinds_extra": [], "order": 0.0}
        results[key] = result
        if result["pass"]:
            passed += 1
            passing_keys.append(key)
        if key in locked and not result["pass"]:
            locked_failing += 1
            print(f"{key}: {json.dumps(result, sort_keys=True)}")

    (design / "render").mkdir(parents=True, exist_ok=True)
    (design / "render/parity.json").write_text(
        json.dumps(results, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    if lock_passing:
        locked.update(passing_keys)
        lock_path.write_text("".join(f"{key}\n" for key in sorted(locked)), encoding="utf-8")
    print(f"parity: {rendered} rendered, {passed} pass, {len(locked)} locked, {locked_failing} locked failing")
    return 1 if locked_failing else 0


if __name__ == "__main__":
    raise SystemExit(main())
