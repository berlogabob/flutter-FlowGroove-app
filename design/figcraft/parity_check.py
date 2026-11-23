"""Helpers for comparing static design labels with Dart source literals."""

import re
from pathlib import Path


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

    spec_kinds = {item.get("kind") for item in spec_flat.get("kinds", [])
                  if item.get("kind")}
    dump_kinds = {item.get("kind") for item in dump.get("kinds", [])
                  if item.get("kind")}
    kinds_missing = sorted(spec_kinds - dump_kinds)
    kinds_extra = sorted(dump_kinds - spec_kinds)

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

    passed = not (missing or extra or kinds_missing or kinds_extra) and order == 1.0
    return {
        "pass": passed,
        "missing": missing,
        "extra": extra,
        "kinds_missing": kinds_missing,
        "kinds_extra": kinds_extra,
        "order": order,
    }
