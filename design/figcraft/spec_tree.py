"""Extract rendered text and semantic node kinds from a FigCraft spec."""


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
        if isinstance(value, str):
            texts.append(value)
        elif isinstance(value, list):
            for item in value:
                add(item)

    def visit(node):
        if isinstance(node, str):
            texts.append(node)
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
            "input": ("label", "hint", "v"),
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
            add(node.get("primary"))
            add("Back")
        elif kind == "bottomnav":
            add(_BOTTOM_NAV)

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
    for overlay in spec.get("overlay", []):
        if isinstance(overlay, dict):
            visit(overlay.get("node"))
        else:
            visit(overlay)

    return {"texts": texts, "kinds": kinds}
