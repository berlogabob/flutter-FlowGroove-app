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


def raw_counts(lib_dir: str) -> dict[str, int]:
    """Count selected raw Flutter style values outside exempt source files."""
    counts = {key: 0 for key in _RAW_PATTERNS}
    root = Path(lib_dir)
    for path in root.rglob("*.dart"):
        relative = path.relative_to(root).as_posix()
        if path.name.endswith((".g.dart", ".freezed.dart")):
            continue
        if relative.startswith("theme/") or relative == "services/export/pdf_service.dart":
            continue
        source = "\n".join(line for line in path.read_text(encoding="utf-8").splitlines() if not ALLOW.search(line))
        for key, pattern in _RAW_PATTERNS.items():
            counts[key] += len(pattern.findall(source))
    return counts


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


LAYOUT_ONLY = {"StandardScreenScaffold", "ToolScreenScaffold", "MenuScopePublisher", "StableSlotText"}


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
    surfaces = json.loads(path.read_text(encoding="utf-8"))
    return len(surfaces), sum(item["spec"] is None for item in surfaces)


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
    metrics["unspecced_screens"] = unspecced
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
