"""Design system metrics counters."""

import json
import re
from pathlib import Path

try:
    from design.diff_lint import ALLOW
except ImportError:
    from diff_lint import ALLOW


_RAW_PATTERNS = {
    "fontSize": re.compile(r"fontSize:\s*\d"),
    "TextStyle": re.compile(r"\bTextStyle\("),
    "EdgeInsets": re.compile(r"EdgeInsets\.(?:all|symmetric|only|fromLTRB)\([^)]*\b\d+(?:\.\d+)?\b"),
    "SizedBox": re.compile(r"SizedBox\((?:width|height):\s*\d"),
    "radius": re.compile(r"(?:BorderRadius\.circular|Radius\.circular)\(\s*\d"),
    "Colors": re.compile(r"\bColors\.(?!transparent\b)[a-z]\w*"),
}


_NUMBER = re.compile(r"\b\d+(?:\.\d+)?\b")
_TWEAK_ARGS = {"color", "fontWeight", "fontStyle", "decoration", "decorationColor", "decorationStyle"}
_RAW_COLOUR = re.compile(r"\bColors\.(?!transparent\b)[a-z]|Color\(\s*0x|Color\.from(?:ARGB|RGBO)\(")


def _call_end(source: str, open_index: int) -> int:
    """Index just past the parenthesis closing the one at ``open_index``."""
    depth = 0
    for i in range(open_index, len(source)):
        depth += (source[i] == "(") - (source[i] == ")")
        if depth == 0:
            return i + 1
    return len(source)


def _value_end(source: str, i: int) -> int:
    """Index of the ',' or closing bracket ending the argument value that contains ``i``."""
    depth = 0
    while i < len(source):
        char = source[i]
        if char in "([{":
            depth += 1
        elif char in ")]}":
            if depth == 0:
                return i
            depth -= 1
        elif char == "," and depth == 0:
            return i
        i += 1
    return len(source)


def _top_level_names(args: str) -> list[str]:
    """Names of the named arguments of a call body (positional arguments give an empty name)."""
    names, depth, start = [], 0, 0
    for i, char in enumerate(args + ","):
        depth += char in "([{" 
        depth -= char in ")]}"
        if char == "," and depth == 0:
            part = args[start:i].strip()
            if part:
                match = re.match(r"(\w+)\s*:", part)
                names.append(match.group(1) if match else "")
            start = i + 1
    return names


def _is_style_tweak(call: str) -> bool:
    """TextStyle(...) that only adjusts colour/weight/style/decoration with non-raw values."""
    body = call[call.index("(") + 1:-1]
    return all(name in _TWEAK_ARGS for name in _top_level_names(body)) and not _RAW_COLOUR.search(body)


def _normalize(expression: str) -> str:
    """Expression key for the allow list: comments dropped, whitespace collapsed."""
    text = " ".join(re.sub(r"//[^\n]*", "", expression).split())
    text = re.sub(r"\s*([()\[\]])\s*", r"\1", text)  # formatting around brackets is not part of the value
    return re.sub(r",(?=[)\]])", "", text)  # nor is a trailing comma


def raw_hits(source: str) -> list[tuple[str, str, int, int]]:
    """Raw style values of a source as (key, expression, start, end). ds-allow lines are not part of the source."""
    hits = []
    for key, pattern in _RAW_PATTERNS.items():
        for match in pattern.finditer(source):
            start, end = match.start(), match.end()
            if key == "TextStyle":
                end = _call_end(source, end - 1)
                if _is_style_tweak(source[start:end]):
                    continue
            elif key in ("EdgeInsets", "SizedBox", "radius"):
                end = _call_end(source, source.index("(", start))  # the whole call, not up to its first digit
                if key == "EdgeInsets" and all(float(n) == 0 for n in _NUMBER.findall(match.group())):
                    continue  # only zeros: nothing raw
            elif key == "fontSize":
                end = _value_end(source, end - 1)
            hits.append((key, _normalize(source[start:end]), start, end))
    return hits


def _lib_sources(lib_dir: str):
    root = Path(lib_dir)
    for path in sorted(root.rglob("*.dart")):
        relative = path.relative_to(root).as_posix()
        if path.name.endswith((".g.dart", ".freezed.dart")):
            continue
        if relative.startswith("theme/") or relative == "services/export/pdf_service.dart":
            continue
        yield relative, "\n".join(line for line in path.read_text(encoding="utf-8").splitlines() if not ALLOW.search(line))


def raw_counts(lib_dir: str) -> dict[str, int]:
    """Count selected raw Flutter style values outside exempt source files."""
    counts = {key: 0 for key in _RAW_PATTERNS}
    for _, source in _lib_sources(lib_dir):
        for key, *_ in raw_hits(source):
            counts[key] += 1
    return counts


def load_allow(path: Path) -> set[tuple[str, str]]:
    """Intentional raw values from lines ``repo path | expression | reason`` (reason required)."""
    allowed = set()
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.strip() or line.startswith("#"):
                continue
            parts = [part.strip() for part in line.split(" | ", 2)]
            if len(parts) == 3 and all(parts):
                allowed.add((parts[0], _normalize(parts[1])))
    return allowed


def unexplained(lib_dir: str, allow_path: Path) -> list[tuple[str, str, str]]:
    """Raw values (path, key, expression) not covered by the allow list; a value inside a listed one is covered."""
    allowed = load_allow(allow_path)
    missing = []
    for relative, source in _lib_sources(lib_dir):
        relative = f"lib/{relative}"
        hits = raw_hits(source)
        spans = [(start, end) for _, expr, start, end in hits if (relative, expr) in allowed]
        for key, expr, start, end in hits:
            if (relative, expr) in allowed or any(a <= start and end <= b for a, b in spans):
                continue
            missing.append((relative, key, expr))
    return missing


def spec_files(specs_dir):
    root = Path(specs_dir)
    return (path for path in root.rglob("*.json") if not any(part.startswith(".") for part in path.relative_to(root).parts))


def spec_offscale(specs_dir: str, tokens_path: str) -> int:
    """Count spacing and radius values absent from the corresponding token set."""
    tokens = json.loads(Path(tokens_path).read_text(encoding="utf-8"))

    def numeric_values(value):
        if isinstance(value, bool):
            return []
        if isinstance(value, (int, float)):
            return [value]
        if isinstance(value, (list, dict)):
            items = value.values() if isinstance(value, dict) else value
            return [number for item in items for number in numeric_values(item)]
        return []

    spacing = set(numeric_values(tokens.get("spacing", {})))
    radius = set(numeric_values(tokens.get("radius", {})))
    total = 0

    def walk(value):
        nonlocal total
        if isinstance(value, dict):
            for key, item in value.items():
                if key in ("pad", "gap"):
                    total += sum(number != 0 and number not in spacing for number in numeric_values(item))
                elif key == "radius":
                    total += sum(number != 0 and number not in radius for number in numeric_values(item))
                walk(item)
        elif isinstance(value, list):
            for item in value:
                walk(item)

    for path in spec_files(specs_dir):
        walk(json.loads(path.read_text(encoding="utf-8")))
    return total


LAYOUT_ONLY = {"StandardScreenScaffold", "ToolScreenScaffold", "MenuScopePublisher", "StableSlotText", "LabeledField"}


def link_counts(connect_path: str, widgets_dir: str, screens_dir: str) -> dict:
    """Measure reused public widget components and their FigCraft links."""
    class_pattern = re.compile(r"^class\s+(\w+)\s+extends\s+(?:Stateless|Stateful|Consumer|ConsumerStateful)Widget\b", re.MULTILINE)
    discovered = set()
    for path in Path(widgets_dir).rglob("*.dart"):
        discovered.update(class_pattern.findall(path.read_text(encoding="utf-8")))

    uses = {name: 0 for name in discovered}
    use_patterns = {name: re.compile(rf"\b{re.escape(name)}\(") for name in discovered}
    for path in Path(screens_dir).rglob("*.dart"):
        source = path.read_text(encoding="utf-8")
        for name, pattern in use_patterns.items():
            uses[name] += len(pattern.findall(source))
    reused = sorted(name for name, count in uses.items() if count >= 3 and name not in LAYOUT_ONLY)

    connect = json.loads(Path(connect_path).read_text(encoding="utf-8"))
    linked_names = set()
    mismatches = 0
    for link in connect.get("links", []):
        component = link.get("component", "")
        name = link.get("name", "").split(".", 1)[0]
        if component.startswith("Icon/"):
            continue
        linked_names.add(name)
        if component != name:
            mismatches += 1
    linked = sorted(set(reused) & linked_names)
    return {
        "reused": reused,
        "linked": linked,
        "unlinked": sorted(set(reused) - set(linked)),
        "name_mismatches": mismatches,
    }


def render_counts(render_dir: str, lock_path: str) -> dict:
    """Summarize render artifacts, parity results, and matrix cells."""
    root = Path(render_dir)
    lock = Path(lock_path)
    locked_names = {line.strip() for line in lock.read_text(encoding="utf-8").splitlines() if line.strip()} if lock.exists() else set()
    parity_path = root / "parity.json"
    parity = json.loads(parity_path.read_text(encoding="utf-8")) if parity_path.exists() else {}
    matrix_path = root / "matrix.json"
    matrix = json.loads(matrix_path.read_text(encoding="utf-8")) if matrix_path.exists() else {}
    rendered_keys = {path.name.split("@", 1)[0] for path in root.glob("*@*.json")}
    passing = {key for key, item in parity.items() if isinstance(item, dict) and item.get("pass") is True}
    return {
        "rendered": len(rendered_keys),
        "locked": len(locked_names),
        "passing": len(passing),
        "locked_passing": len(passing & locked_names),
        "matrix_ok": sum(1 for status in matrix.values() if status == "ok"),
        "matrix_total": len(matrix),
    }


def surface_counts(path: Path) -> tuple[int, int]:
    """(surfaces, unspecced) over app-built surfaces; kind "system" (OS/stock pickers) needs no spec."""
    surfaces = [item for item in json.loads(path.read_text(encoding="utf-8")) if item.get("kind") != "system"]
    return len(surfaces), sum(item["spec"] is None for item in surfaces)


def system_surface_count(path: Path) -> int:
    return sum(item.get("kind") == "system" for item in json.loads(path.read_text(encoding="utf-8")))


def render_coverage(keys_path: Path, surfaces_path: Path) -> str:
    """k8: render keys / distinct specs among inventory surfaces."""
    keys = [line.strip() for line in keys_path.read_text(encoding="utf-8").splitlines()]
    listed = sum(1 for key in keys if key and not key.startswith("#"))
    specs = {item["spec"] for item in json.loads(surfaces_path.read_text(encoding="utf-8")) if item["spec"]}
    return f"{listed}/{len(specs)}"


def summarize(links: dict, renders: dict, routed: int, offscale: int, raw: dict) -> dict:
    """KPI line: k1 linked/reused widgets, k2 rendered/routed screens, k3 locked screens passing parity,
    k4 off-scale spec values, k5 raw code values, k6 FigCraft names that differ from the Dart class, k7 matrix."""
    return {
        "k1": f"{len(links['linked'])}/{len(links['reused'])}",
        "k1_unlinked": links["unlinked"],
        "k2": f"{renders['rendered']}/{routed}",
        "k3": renders["locked_passing"],
        "k4": offscale,
        "k5": raw,
        "k6": links["name_mismatches"],
        "k7": f"{renders['matrix_ok']}/{renders['matrix_total']}",
    }


def main(argv: list[str]) -> int:
    """Print current design metrics, optionally appending a dated trend row."""
    import argparse
    import datetime
    import subprocess

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--append", action="store_true")
    args = parser.parse_args(argv)

    repo = Path(__file__).resolve().parent.parent
    specs = repo / "design/figcraft/specs"
    links = link_counts(str(repo / "design/figcraft/figcraft.connect.json"), str(repo / "lib/widgets"), str(repo / "lib/screens"))
    renders = render_counts(str(repo / "design/render"), str(repo / "design/parity_lock.txt"))
    routed, unspecced = surface_counts(repo / "design/surfaces.json")
    metrics = summarize(links, renders, routed,
                        spec_offscale(str(specs), str(repo / "design/tokens/tokens.json")), raw_counts(str(repo / "lib")))
    metrics["k5_unexplained"] = len(unexplained(str(repo / "lib"), repo / "design/raw_allow.txt"))
    metrics["unspecced_screens"] = unspecced
    metrics["system_surfaces"] = system_surface_count(repo / "design/surfaces.json")
    metrics["k8"] = render_coverage(repo / "design/render_keys.txt", repo / "design/surfaces.json")
    if args.append:
        metrics["date"] = datetime.date.today().isoformat()
        metrics["sha"] = subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"], cwd=repo, text=True
        ).strip()
    line = json.dumps(metrics, sort_keys=True)
    print(line)
    if args.append:
        with (repo / "design/metrics.jsonl").open("a", encoding="utf-8") as output:
            output.write(line + "\n")
    return 0


if __name__ == "__main__":
    import sys
    raise SystemExit(main(sys.argv[1:]))
