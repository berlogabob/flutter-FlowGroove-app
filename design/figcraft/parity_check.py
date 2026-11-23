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
