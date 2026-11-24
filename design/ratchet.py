"""Fail the design check when a tracked metric grows."""

import argparse
import json
from pathlib import Path

if __package__:
    from design.metrics import link_counts, raw_counts, spec_offscale, surface_counts, unexplained
else:
    from metrics import link_counts, raw_counts, spec_offscale, surface_counts, unexplained


def check(current: dict[str, int], baseline: dict[str, int]) -> list[str]:
    """Return messages for metrics that exceed their recorded baseline."""
    return [
        f"{key} grew {baseline[key]} -> {value}"
        for key, value in sorted(current.items())
        if key in baseline and value > baseline[key]
    ]


def update_baseline(current: dict[str, int], path: Path) -> None:
    """Write current values that lower the existing baseline."""
    baseline = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    for key, value in current.items():
        if key not in baseline or value < baseline[key]:
            baseline[key] = value
    path.write_text(json.dumps(baseline, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def unspecced_screens(screens_dir: Path, specs_dir: Path) -> int:
    """Count screen Dart files that have no matching spec source."""
    sources = set()
    for path in specs_dir.rglob("*.json"):
        if path.name.startswith("."):
            continue
        spec = json.loads(path.read_text(encoding="utf-8"))
        source = spec.get("source")
        if isinstance(source, str):
            sources.add(source.split(":", 1)[0])  # "path:line" anchors cover the file
    repo_root = screens_dir.parent.parent
    count = 0
    for path in screens_dir.rglob("*_screen.dart"):
        relative = path.relative_to(repo_root).as_posix()
        if relative not in sources:
            count += 1
    return count


def current_counts(repo: Path) -> dict[str, int]:
    specs = repo / "design/figcraft/specs"
    links = link_counts(
        str(repo / "design/figcraft/figcraft.connect.json"),
        str(repo / "lib/widgets"),
        str(repo / "lib/screens"),
    )
    current = {
        "k4": spec_offscale(str(specs), str(repo / "design/tokens/tokens.json")),
        **{f"k5.{key}": value for key, value in raw_counts(str(repo / "lib")).items()},
        "k5_unexplained": len(unexplained(str(repo / "lib"), repo / "design/raw_allow.txt")),
        "unspecced_screens": unspecced_screens(repo / "lib/screens", specs),
        "unlinked_reused": len(links["unlinked"]),
        # Sheets, dialogs, pickers and tool states too (F83), from the inventory.
        "unspecced_surfaces": surface_counts(repo / "design/surfaces.json")[1],
    }
    return current


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--update", action="store_true", help="lower ratchet values to current counts")
    args = parser.parse_args(argv)
    repo = Path(__file__).resolve().parent.parent
    ratchet_path = repo / "design/ratchets.json"
    current = current_counts(repo)
    if args.update:
        update_baseline(current, ratchet_path)
        return 0
    baseline = json.loads(ratchet_path.read_text(encoding="utf-8"))
    messages = check(current, baseline)
    for message in messages:
        print(message)
    return 1 if messages else 0


if __name__ == "__main__":
    raise SystemExit(main())
