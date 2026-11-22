#!/usr/bin/env python3
"""Flag Dart ternaries that change layout and chips that add a checkmark."""

import argparse
import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOKEN = re.compile(
    r"//[^\n]*|/\*.*?\*/"
    r"|r?(?:'''[\s\S]*?'''|\"\"\"[\s\S]*?\"\"\"|'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\")"
    r"|\w+|\?\?=?|\?\.{1,2}|\?\[|==|!=|&&|\|\||[^\s]",
    re.S,
)
CLOSERS = {"(": ")", "[": "]", "?[": "]", "{": "}"}
GEOMETRY = {"fontWeight", "fontSize", "iconSize", "size", "padding", "width", "height"}
CHIPS = {"FilterChip", "ChoiceChip"}
INSETS = {"EdgeInsets", "EdgeInsetsDirectional"}


def named_geometry(part, owner):
    if len(part) < 2 or part[1] != ":" or part[0] not in GEOMETRY:
        return None
    name = part[0]
    if name == "width" and owner in {"BorderSide", "Border.all"}:
        return "border width"
    if name == "iconSize" or (name == "size" and owner == "Icon"):
        return "icon size"
    return name


def branch_kind(tokens, groups):
    while len(tokens) == 1 and tokens[0].start() in groups:
        tokens = groups[tokens[0].start()]
    value = [token.group() for token in tokens]
    if value[:1] == ["const"]:
        value = value[1:]
    if len(value) >= 3 and value[1] == "." and value[2] in INSETS | {"Border", "BorderSide"}:
        value = value[2:]
    if value[:2] == ["BorderSide", "("]:
        return "BorderSide"
    if value == ["BorderSide", ".", "none"]:
        return "BorderSide.none"
    if value[:4] == ["Border", ".", "all", "("]:
        return "Border.all"
    if value == ["null"]:
        return "null"
    if value and value[0] in INSETS:
        return "EdgeInsets"
    return None


def check_part(part, owner, inherited, groups, hits):
    values = [token.group() for token in part]
    if owner in CHIPS and values == ["showCheckmark", ":", "true"]:
        hits.append((part[0].start(), f"{owner} showCheckmark: true"))
    geometry = named_geometry(values, owner)
    inset = owner and owner.split(".")[0] in INSETS
    questions = []
    for index, value in enumerate(values):
        if value == "?":
            questions.append(index)
        elif value == ":" and questions:
            question = questions.pop()
            # Shorten the false arm at the colon of an enclosing ternary.
            end = index + 1
            depth = 0
            while end < len(values):
                if values[end] == ":" and depth == 0:
                    break
                depth += (values[end] == "?") - (values[end] == ":")
                end += 1
            arms = {
                branch_kind(part[question + 1:index], groups),
                branch_kind(part[index + 1:end], groups),
            }
            pattern = geometry or inherited
            if arms == {"BorderSide", "BorderSide.none"}:
                pattern = "BorderSide vs BorderSide.none"
            elif arms == {"Border.all", "null"}:
                pattern = "Border.all vs null"
            elif not pattern and (inset or "EdgeInsets" in arms):
                pattern = "EdgeInsets"
            if pattern:
                location = part[0] if geometry else part[question]
                start = 2 if values[1:2] == [":"] else 0
                condition = " ".join(values[start:question]).replace(" . ", ".")
                hits.append((location.start(), f"{pattern} [{condition}]"))


def scan(source):
    tokens = [
        token for token in TOKEN.finditer(source)
        if not token.group().startswith(("//", "/*"))
    ]
    hits = []
    groups = {}

    def walk(index, closer=None, owner=None, inherited=None, group_start=None):
        part = []
        while index < len(tokens):
            token = tokens[index]
            value = token.group()
            index += 1
            if value in {closer, ",", ";"}:
                check_part(part, owner, inherited, groups, hits)
                if value == closer:
                    if group_start is not None:
                        groups[group_start] = part
                    return index
                group_start = None
                part = []
            elif value in CLOSERS:
                prefix = [item.group() for item in part[-3:]]
                callee = None
                if value == "(" and prefix and prefix[-1].isidentifier():
                    callee = prefix[-1]
                    if len(prefix) == 3 and prefix[1] == "." and prefix[0] in INSETS | {"Border"}:
                        callee = "".join(prefix)
                geometry = named_geometry([item.group() for item in part[:2]], owner)
                # Carry the layout property into grouping parentheses and EdgeInsets arguments.
                inside = None
                if value == "(" and (
                    callee is None or callee.split(".")[0] in INSETS
                ):
                    inside = geometry or inherited
                part.append(token)
                grouped = token.start() if value == "(" and callee is None else None
                index = walk(index, CLOSERS[value], callee, inside, grouped)
            else:
                part.append(token)
        check_part(part, owner, inherited, groups, hits)
        return index

    walk(0)
    for offset, pattern in sorted(set(hits)):
        yield source.count("\n", 0, offset) + 1, pattern


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", type=Path, default=Path("lib"))
    path = parser.parse_args().path
    if not path.exists():
        parser.error(f"path does not exist: {path}")
    with (ROOT / "design/stable_layout_allow.txt").open() as allow_file:
        rows = csv.reader(
            (line for line in allow_file if line.strip() and not line.lstrip().startswith("#")),
            skipinitialspace=True,
        )
        allowed = set()
        for filename, pattern, reason in rows:
            if not reason.strip():
                raise ValueError(f"missing reason for {filename}, {pattern}")
            allowed.add((filename.strip(), pattern.strip()))

    failed = False
    files = sorted(path.rglob("*.dart")) if path.is_dir() else [path]
    for filename in files:
        if filename.suffix != ".dart" or filename.name.endswith(".g.dart"):
            continue
        absolute = filename.resolve()
        relative = absolute.relative_to(ROOT).as_posix() if absolute.is_relative_to(ROOT) else None
        for line, pattern in scan(filename.read_text(encoding="utf-8")):
            if (relative, pattern) not in allowed:
                print(f"{filename}:{line}: {pattern}")
                failed = True
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
