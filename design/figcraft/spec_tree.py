"""Extract rendered text and semantic node kinds from a FigCraft spec."""

import json


_KINDS = {
    "button",
    "chip",
    "input",
    "tile",
    "switchrow",
    "iconbtn",
    "fab",
    "card",
    "badge",
    "avatar",
    "slider",
    "progress",
    "checkbox",
    "switch",
    "segmented",
    "tabs",
    "appbar",
    "divider",
    "dialog",
}
_BOTTOM_NAV = ["Home", "Songs", "Bands", "Setlists", "More"]


def flatten(spec: dict, icons: set[str]) -> dict:
    """Return visible strings and meaningful kinds in rendered document order."""
    texts = []
    kinds = []

    def add(value):
        # The dump drops blank text (an empty field value never appears in it).
        if isinstance(value, str):
            if value.strip():
                texts.append(value)
        elif isinstance(value, list):
            for item in value:
                add(item)

    def visit(node):
        if isinstance(node, str):
            add(node)
            return
        if isinstance(node, list):
            for child in node:
                visit(child)
            return
        if not isinstance(node, dict):
            return

        kind = node.get("t")
        if kind in _KINDS:
            kinds.append(kind)

        fields = {
            "text": ("v",),
            "button": ("v",),
            "chip": ("v",),
            # A field's typed value is an EditableText, not a Text: the dump never captures it.
            "input": ("label", "hint"),
            "tile": ("title", "sub", "trail"),
            "switchrow": ("title", "sub"),
            "tabs": ("items",),
            "segmented": ("items",),
            "section": ("v", "action"),
            "badge": ("v",),
            "appbar": ("v", "sub"),
            "dialog": ("title",),
            "fab": ("v",),
        }
        for field in fields.get(kind, ()):
            value = node.get(field)
            if kind == "tile" and field == "trail":
                if isinstance(value, str) and value in icons:
                    continue
                if isinstance(value, list):
                    value = [part for part in value if not (isinstance(part, str) and part in icons)]
            add(value)
        if kind == "actionbar":
            # AppBottomBar draws [Back] [title | primary] [Menu]; the title sits above the nav labels.
            add(node.get("title"))
            add(node.get("primary"))
            add("Back")
            if node.get("menu", True):
                add("Menu")
        elif kind == "appbar":
            # The back arrow and icon-name actions are IconButtons in the app.
            actions = node.get("actions") or []
            if node.get("back", True) or any(isinstance(a, str) and a in icons for a in actions):
                kinds.append("iconbtn")
        elif kind == "bottomnav":
            add(_BOTTOM_NAV)
        # Song Map nodes, in the order the app lays their texts out (top to bottom, then left to right).
        elif kind == "key":
            kinds.append("button")
            add(node.get("v"))
        elif kind == "row" and node.get("c") and all(
            isinstance(child, dict) and child.get("t") == "pad" for child in node["c"]
        ):
            for field in ("label", "letter", "sub"):
                add([child.get(field) for child in node["c"]])
            return
        elif kind == "overview":
            add([block.get("letter") for block in node.get("sections", [])])
        elif kind == "zoomwave":
            parts = node.get("parts", [])
            add([part.get("letter") for part in parts])
            add([f"{part['bars']} bar" if part["bars"] == 1 else f"{part['bars']} bars" for part in parts])
            start = node.get("startBar", 1)
            add([str(bar) for bar in range(start, start + sum(part["bars"] for part in parts))])
        elif kind == "transport":
            add(["Pause" if node.get("playing") else "Play", "Loop", "Click", "Drums", "Count-in"])

        # Container children and nested node-valued properties retain source order.
        children = node.get("c")
        if children is not None:
            visit(children)
        for key in ("lead", "trail", "actions", "node"):
            value = node.get(key)
            if isinstance(value, (dict, list)):
                visit(value)

    for section in ("top", "body", "bottom"):
        visit(spec.get(section, []))
    overlay_from = len(texts)
    has_avatar = '"t": "avatar"' in json.dumps(spec)
    for overlay in spec.get("overlay", []):
        node = overlay.get("node") if isinstance(overlay, dict) else None
        if has_avatar and isinstance(node, dict) and node.get("t") == "text" and len(str(node.get("v", "")).strip()) <= 2:
            continue  # an initial drawn over an avatar: the dump hides avatar initials
        if isinstance(overlay, dict):
            visit(overlay.get("node"))
        else:
            visit(overlay)

    flat = {"texts": texts, "kinds": kinds}
    if spec.get("overlay") and overlay_from < len(texts):
        # The dump orders by screen position, so a sheet over the screen interleaves with the
        # screen's texts; the frame cannot say how. Order holds within each part, not across them.
        flat["overlay_from"] = overlay_from
    if spec.get("modal"):
        flat["modal"] = spec["modal"]  # parity ignores the backdrop's extras (F94)
    return flat
