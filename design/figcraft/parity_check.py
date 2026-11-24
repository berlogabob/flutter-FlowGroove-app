"""Helpers for comparing static design labels with Dart source literals."""

import re
import json
import sys
from pathlib import Path

try:
    from spec_tree import flatten
except ImportError:  # Imported as part of the design.figcraft package.
    from design.figcraft.spec_tree import flatten


def _skip_string(source: str, i: int) -> tuple[int, str, bool]:
    """Read the Dart string literal opening at ``source[i]``.

    Returns (index after it, raw content, has_interpolation). Handles raw strings,
    triple quotes and nested ``${...}`` expressions that contain strings.
    """
    raw = i > 0 and source[i - 1] == "r" and not (i > 1 and source[i - 2].isalnum())
    quote = source[i]
    triple = source.startswith(quote * 3, i)
    delimiter = quote * 3 if triple else quote
    i += len(delimiter)
    start = i
    interpolated = False
    while i < len(source):
        if source.startswith(delimiter, i):
            return i + len(delimiter), source[start:i], interpolated
        char = source[i]
        if char == "\\" and not raw:
            i += 2
        elif char == "\n" and not triple:
            return i, source[start:i], interpolated  # unterminated: stop at the line end
        elif char == "$" and not raw:
            interpolated = True
            if source.startswith("{", i + 1):
                depth, i = 1, i + 2
                while i < len(source) and depth:
                    if source[i] in "'\"":
                        i = _skip_string(source, i)[0]
                        continue
                    depth += (source[i] == "{") - (source[i] == "}")
                    i += 1
            else:
                i += 1
        else:
            i += 1
    return i, source[start:], interpolated


def dart_strings(source: str):
    """Yield (content, has_interpolation) for every string literal, skipping comments."""
    i = 0
    while i < len(source):
        if source.startswith("//", i):
            end = source.find("\n", i)
            i = len(source) if end < 0 else end
        elif source.startswith("/*", i):
            end = source.find("*/", i + 2)
            i = len(source) if end < 0 else end + 2
        elif source[i] in "'\"":
            i, content, interpolated = _skip_string(source, i)
            yield content, interpolated
        else:
            i += 1


def lib_literals(lib_dir: str) -> set[str]:
    """Return non-interpolated, quoted string literals found under ``lib_dir``."""
    literals = set()
    for dart_file in Path(lib_dir).rglob("*.dart"):
        for content, interpolated in dart_strings(dart_file.read_text(encoding="utf-8")):
            value = content.strip()
            if not interpolated and "$" not in value:
                literals.add(value)
    return literals


def static(texts: list[str], literals: set[str]) -> list[str]:
    """Keep text entries that occur as static source literals, preserving order."""
    return [text for text in texts if text in literals]


MIN_LABELS = 2
ROW_TOLERANCE = 4.0  # px: texts whose tops differ by less sit on one row (a 3.5 px baseline offset)


def row_ordered(items: list) -> list[str]:
    """Dump labels in row reading order: rows (tops within ROW_TOLERANCE of the row's first), then x.

    Items without positions keep their given order.
    """
    def label(item):
        return item if isinstance(item, str) else item.get("v", "")

    if not all(isinstance(item, dict) and "x" in item and "y" in item for item in items):
        return [label(item) for item in items]
    rows: list[list[dict]] = []
    for item in sorted(items, key=lambda item: item["y"]):
        if rows and item["y"] - rows[-1][0]["y"] < ROW_TOLERANCE:
            rows[-1].append(item)
        else:
            rows.append([item])
    return [label(item) for row in rows for item in sorted(row, key=lambda item: item["x"])]


def _lcs(left: list[str], right: list[str]) -> int:
    previous = [0] * (len(right) + 1)
    for a in left:
        current = [0]
        for index, b in enumerate(right, 1):
            current.append(previous[index - 1] + 1 if a == b else max(previous[index], current[-1]))
        previous = current
    return previous[-1]


def debug_only_labels(path: Path) -> dict[str, str]:
    """Labels drawn only under ``kDebugMode`` (never shipped), from lines ``label<TAB>lib/file.dart``."""
    labels = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.startswith("#"):
                label, _, source = line.partition("\t")
                labels[label] = source.strip()
    return labels


def in_debug_conditional(source: str, label: str) -> bool:
    """True when a literal ``label`` sits inside the widget guarded by an ``if (kDebugMode ...)``."""
    for match in re.finditer(r"\bif\s*\(\s*kDebugMode\b", source):
        i = source.index("(", match.start())
        depth = 0
        while i < len(source):  # skip the condition
            depth += (source[i] == "(") - (source[i] == ")")
            i += 1
            if depth == 0:
                break
        start, depth = i, 0
        while i < len(source):  # the guarded element: up to the comma/closer ending it
            char = source[i]
            if char in "([{":
                depth += 1
            elif char in ")]}":
                depth -= 1
                if depth < 0:
                    break
            elif char == "," and depth == 0:
                break
            i += 1
        # The spread form `...[ a, b ]` and `{ ... }` bodies hold the label at nested depth.
        body = source[start:i]
        if re.match(r"\s*(\.\.\.)?\s*[\[{]", body):
            body = source[start:_close(source, start + re.match(r"\s*(\.\.\.)?\s*", body).end())]
        if any(content.strip() == label for content, _ in dart_strings(body)):
            return True
    return False


def _close(source: str, i: int) -> int:
    depth = 0
    while i < len(source):
        depth += (source[i] in "([{") - (source[i] in ")]}")
        i += 1
        if depth == 0:
            break
    return i
KIND_ALIASES = {"switchrow": "switch"}


def compare(spec_flat: dict, dump: dict, literals: set[str], ignore: frozenset = frozenset()) -> dict:
    """Compare flattened spec labels and kinds with a rendered dump.

    ``ignore``: debug-only labels (see debug_only.txt); the dump shows them, the shipped app does not.
    """
    def labels(items):
        return [item if isinstance(item, str) else item.get("v", "")
                for item in items]

    spec_texts = [label for label in labels(spec_flat.get("texts", []))]
    spec_labels = [label for label in spec_texts if label in literals and label not in ignore]
    dump_labels = [label for label in labels(dump.get("texts", []))
                   if label in literals and label not in ignore]
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
    # Every dump occurrence counts: a label repeated elsewhere on screen (a background
    # "F" before the sheet's "F") must not hide the occurrence in the right place.
    def dump_order(texts):
        return [label for label in texts if label in literals and label not in ignore and label in common]

    # A sheet over the screen interleaves with it in the dump (position order): each part keeps its own order.
    cut = spec_flat.get("overlay_from")
    parts = [spec_texts] if cut is None else [spec_texts[:cut], spec_texts[cut:]]
    spec_parts = [list(dict.fromkeys(label for label in part if label in common)) for part in parts]
    kept = sum(map(len, spec_parts))
    # Texts a few px apart may be one row (centred in a taller one) or two: either reading order is the dump's.
    readings = [dump_order(labels(dump.get("texts", []))), dump_order(row_ordered(dump.get("texts", [])))]
    order = max(sum(_lcs(part, reading) for part in spec_parts) for reading in readings) / kept if kept else 1.0

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

    ignore = frozenset(debug_only_labels(root / "design/figcraft/debug_only.txt"))
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
            result = compare(spec_flat, json.loads(dump_path.read_text(encoding="utf-8")), literals, ignore)
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
