"""Build FlowGroove screens in a running FigCraft app from JSON specs.

FigCraft must run with its control channel:
  /Applications/FigCraft.app/Contents/MacOS/FigCraft --control 47321 \
    --automation-read-root <repo> --automation-write-root <repo>/design

  python3 design/figcraft/build.py setup            # new doc: variables, text styles, pages, components
  python3 design/figcraft/build.py screen specs/x.json [--png out.png]
  python3 design/figcraft/build.py all              # setup + every spec + save
  python3 design/figcraft/build.py dryrun           # validate all commands without FigCraft
Spec format: design/figcraft/SPEC.md
"""
import glob, json, os, random, re, socket, subprocess, sys
from tempfile import TemporaryDirectory
from unittest.mock import patch
from contrast import matrix as contrast_matrix
from contrast import BADGE_SECTION1_SHADE, BADGE_WHITE_SECTIONS, PAD_SURFACES

HERE = os.path.dirname(os.path.abspath(__file__))
PORT = int(os.environ.get("FIGCRAFT_PORT", "47321"))
W, H = 412, 915
COL = "MonoPulse"
MODES = {"dark": "Dark", "light": "Light"}

# ---------------------------------------------------------------- transport
_sock = _rf = None


def raw(method, params=None, timeout_ms=None):
    global _sock, _rf
    if _sock is None:
        _sock = socket.create_connection(("127.0.0.1", PORT))
        _rf = _sock.makefile("rb")
    req = {"id": 1, "method": method, "params": params or {}}
    if timeout_ms:
        req["timeoutMs"] = timeout_ms
    _sock.sendall((json.dumps(req) + "\n").encode())
    r = json.loads(_rf.readline())
    if not r.get("ok"):
        raise RuntimeError(f"{method}: {r.get('error')}")
    return r.get("result")


def ex(command, params=None):
    return raw("engine.execute", {"command": command, "params": params or {}}, 300000)


def command_keys(doc):
    # Keep only the outer parameter list, dropping nested schemas and explanations.
    depth = 0
    outer = doc.lstrip().startswith("{")
    text = []
    for token in re.findall(r'"(?:\\.|[^"\\])*"|.', doc, re.S):
        if token in ("{", "[", "("):
            depth += 1
        elif token in ("}", "]", ")"):
            depth -= 1
            if outer and depth == 0:
                break
        elif depth == int(outer):
            text.append(token)
    return set(re.findall(r"(?:^|,|\s\|)\s*([A-Za-z_]\w*)", "".join(text)))


class DryTransport:
    def __init__(self, commands):
        self.keys = {row["id"]: command_keys(row["params"]) for row in commands}
        # node.set lists editable properties. Its envelope is omitted, and
        # inspect.readyForDev documents the devStatus key on node.set.
        if "node.set" in self.keys:
            self.keys["node.set"].update(("ids", "props"))
            if any("node.set {devStatus}" in row["params"] for row in commands):
                self.keys["node.set"].add("devStatus")
        self.calls, self.problems = [], {}
        self.pages = {"Page:0": "Page 1"}
        self.nodes, self.inherited = {}, set()
        self.component_sets, self.properties = {}, {}
        self.page = "Page:0"
        # The user's own document, saved to disk and open first, like the live app.
        self.documents = [{"id": 1, "name": "Working document", "path": "/dry/working.figcraft",
                           "dirty": False, "active": True}]

    PROPERTY_TYPES = ("boolean", "text", "instanceSwap", "variant", "slot")

    def check_property(self, p, layer, label):
        """A property needs a known type and, for text, a TEXT layer (FigCraft: text properties
        bind to text layers, so a label inside a nested instance cannot be one)."""
        name = f"property {p.get('name')!r}"
        if p.get("type") not in self.PROPERTY_TYPES:
            self.problems.setdefault(f"component.addProperty: {name} has type {p.get('type')!r}, "
                                     f"expected one of {'|'.join(self.PROPERTY_TYPES)}", label)
        if layer is None:
            return
        node = self.nodes.get(layer)
        if node is None and isinstance(layer, str):  # a layer name inside the component
            stack = [self.nodes.get(p.get("id"), {"children": []})]
            while stack and node is None:
                top = stack.pop()
                node = next((c for c in top["children"] if c["name"] == layer), None)
                stack.extend(top["children"])
        if node is None:
            self.problems.setdefault(f"component.addProperty: {name} binds unknown layer {layer!r}", label)
        elif p.get("type") == "text" and node["type"] != "TEXT":
            self.problems.setdefault(f"component.addProperty: {name} is a text property bound to "
                                     f"{node['type']} layer {node['name']!r}, not a text layer", label)

    def __call__(self, method, params, timeout_ms=None):
        assert method == "engine.execute", method
        return self.execute(params["command"], params["params"])

    def execute(self, command, p, label="document", refs=None):
        self.calls.append((command, p))
        node_id = f"Dry:{len(self.calls)}"
        if command not in self.keys:
            self.problems.setdefault(f"{command}: unknown command", label)
        else:
            for key in p.keys() - self.keys[command]:
                self.problems.setdefault(f"{command}: undocumented parameter {key!r}", label)

        if command == "command.batch":
            results, batch_refs = [], {}
            for cmd in p["commands"]:
                result = self.execute(cmd["command"], cmd.get("params", {}), p.get("label", label), batch_refs)
                results.append(result)
                if "as" in cmd:
                    batch_refs[cmd["as"]] = result
            return results

        def resolve(target):
            if refs is None or not isinstance(target, dict) or "$ref" not in target:
                return target
            result = refs[target["$ref"]]
            for field in target.get("field", "id").split("/"):
                result = result[int(field)] if isinstance(result, list) else result[field]
            return result

        if command == "doc.list":
            return [dict(d, index=i) for i, d in enumerate(self.documents)]
        if command == "doc.switch":
            if not 0 <= p["index"] < len(self.documents):
                self.problems.setdefault(f"doc.switch: no document at index {p['index']}", label)
            else:
                for i, d in enumerate(self.documents):
                    d["active"] = i == p["index"]
        if command == "file.new":
            for d in self.documents:
                d["active"] = False
            self.documents.append({"id": len(self.documents) + 1, "name": p.get("name", "Untitled"),
                                   "path": None, "dirty": True, "active": True})
            self.pages, self.page = {"Page:0": "Page 1"}, "Page:0"
        if command in ("file.save", "file.saveAs", "library.publish"):
            self.problems.setdefault(f"{command}: a rebuild must not save or publish", label)
        if command == "page.list":
            return [{"id": pid, "name": name} for pid, name in self.pages.items()]
        if command == "page.add":
            self.pages[node_id] = p["name"]
        if command == "page.rename":
            self.pages[p["id"]] = p["name"]
        if command == "page.select":
            self.page = p["id"]
        if command == "variable.create":
            return {"id": f"VariableID:{len(self.calls)}"}
        if command == "node.create":
            node = self.nodes[node_id] = {"id": node_id, "name": p.get("name", p["type"]),
                                          "type": p["type"].upper(), "page": self.page, "children": []}
            parent = resolve(p.get("parent"))
            if parent in self.nodes:
                self.nodes[parent]["children"].append(node)
        if command in ("instance.create", "edit.duplicate"):
            copies = {}

            def clone(node, cid, kind):
                copies[node["id"]] = cid
                copy = self.nodes[cid] = dict(node, id=cid, type=kind)
                copy["children"] = [clone(child, f"{cid}:{i}", child["type"])
                                    for i, child in enumerate(node["children"])]
                self.inherited.update(child["id"] for child in copy["children"])
                return copy

            if command == "instance.create":
                clone(self.nodes[p["component"]], node_id, "INSTANCE")
            else:
                ids = [f"{node_id}:{i}" for i in range(len(p["ids"]))]
                for source, cid in zip(p["ids"], ids):
                    clone(self.nodes[resolve(source)], cid, "INSTANCE")
                return {"ids": ids, "map": copies}
        if command == "node.reparent":
            parent = resolve(p["parent"])
            self.nodes[parent]["children"].extend(self.nodes[resolve(t)] for t in p["ids"])
        if command == "node.set":
            for target in p.get("ids", []):
                tid = resolve(target)
                if tid in self.inherited:
                    self.problems.setdefault("node.set: cannot edit a layer inherited from a main component", label)
                if tid in self.nodes and "name" in p.get("props", {}):
                    self.nodes[tid]["name"] = p["props"]["name"]
        if command == "node.get":
            if p.get("outline"):
                return self.nodes[p["id"]]
            return {"absoluteBounds": {"y": 0, "height": 100}, "x": 0, "y": 0}
        if command == "node.find":
            ids = [n["id"] for n in self.nodes.values() if n["page"] == self.page
                   and p.get("name", "").casefold() in n["name"].casefold()
                   and n["type"] == p.get("type", n["type"]).upper()]
            return {"ids": ids[:p.get("limit", 100)], "total": len(ids)}
        if command == "component.combineVariants":
            self.component_sets.update(dict.fromkeys(p["ids"], node_id))
        if command == "component.addProperty":
            self.check_property(p, resolve(p.get("layer")), label)
            self.properties.setdefault(p["id"], []).append(
                {key: p[key] for key in ("type", "name", "default") if key in p})
        if command == "component.properties":
            return {"properties": self.properties.get(self.component_sets.get(p["id"], p["id"]), [])}
        if command == "inspect.componentCode":
            return {"connected": {"code": "Widget()"}}
        if command == "image.place":
            return {"id": node_id, "height": H}
        return {"id": node_id}


# ---------------------------------------------------------------- tokens
TOKENS_JSON = os.path.join(HERE, "..", "tokens", "tokens.json")  # the source of truth, see design/tokens/tokens.py
TOK = json.load(open(TOKENS_JSON))


def _resolve(name):
    e = TOK["color"][name]
    return e["value"] if "value" in e else _resolve(e["alias"])


PALETTE = {k: (m["dark"], m["light"]) for k, m in TOK["palette"].items()}  # MonoPulsePalette
BRAND = {k: _resolve(k) for k in TOK["color"] if k not in PALETTE}  # theme-invariant MonoPulseColors
FAMILY = TOK["font"]  # body / display / control


def figcraft_style(family, weight):
    """FigCraft face for a Flutter weight. Marcellus ships Regular only; Arial has no Medium."""
    if family == FAMILY["display"]:
        return "Regular"
    if family == FAMILY["control"]:
        return "Bold" if weight >= 500 else "Regular"
    return {400: "Regular", 500: "Medium", 600: "SemiBold", 700: "Bold"}[weight]


TYPE = {}  # name -> (family, FigCraft style, size, height multiplier | None, letter spacing px | None)
for _k, _t in TOK["type"].items():
    _fam = FAMILY[_t["family"]]
    TYPE[_k] = (_fam, figcraft_style(_fam, TOK["fontWeight"][_t["weight"]]), _t["size"], _t.get("height"),
                _t.get("letterSpacing"))
DOC_TYPE = {"caption": (FAMILY["body"], "Regular", 12, None, None), "mono": ("Menlo", "Regular", 13, None, None)}
TYPE.update(DOC_TYPE)  # design-only styles for the Foundations / Docs pages; never pulled into code
ICONS = {}
with open(os.path.join(HERE, "icons.txt")) as f:
    for line in f:
        n, cp = line.split()
        ICONS[n] = int(cp, 16)
# Icons page and Code Connect cover only the glyphs the app uses (ICONS stays the full codepoint lookup).
USED_ICONS = sorted({m for m in re.findall(r"Icons\.([a-z0-9_]+)", "".join(
    open(os.path.join(r, f)).read() for r, _, fs in os.walk(os.path.join(HERE, "..", "..", "lib"))
    for f in fs if f.endswith(".dart"))) if m in ICONS})


def color(c):
    if c is None or c == "none":
        return "none"
    if isinstance(c, str) and c.startswith("#"):
        return c
    if c in PALETTE or c in BRAND:
        return {"$var": f"{COL}/{c}"}
    raise ValueError(f"unknown colour token {c!r}")


def text_props(style, col, extra=None):
    fam, sty, size = TYPE[style][:3]
    p = {"textStyle": f"Type/{style}", "fill": color(col)}
    p.update(extra or {})
    return p, (fam, sty, size)


# ---------------------------------------------------------------- spec -> commands
class Emit:
    def __init__(self, mode="dark"):
        self.cmds, self.n = [], 0
        self.named_instances = {}
        self.mode = mode

    def ref(self):
        self.n += 1
        return f"n{self.n}"

    def create(self, typ, parent, name=None, props=None, text=None, w=None, h=None):
        r = self.ref()
        p = {"type": typ, "props": props or {}, "select": False}
        if parent is not None:
            p["parent"] = pref(parent)
        if name:
            p["name"] = name
        if text is not None:
            p["text"] = text
        if w is not None:
            p["width"] = w
        if h is not None:
            p["height"] = h
        self.cmds.append({"command": "node.create", "params": p, "as": r})
        self.cmds += bind_cmds({"$ref": r}, p["props"])
        return r


def size_props(node, pdir, default_main="hug", default_cross=None):
    """w/h -> sizingH/V. pdir = parent auto layout direction ('h'|'v')."""
    out = {}
    for key, axis in (("w", "H"), ("h", "V")):
        v = node.get(key)
        if v is None:
            continue
        if isinstance(v, (int, float)):
            out["width" if key == "w" else "height"] = v
            out["sizing" + axis] = "fixed"
        else:
            out["sizing" + axis] = v
    return out


SPACING = TOK["spacing"]  # MonoPulseSpacing
RADII = TOK["radius"]  # MonoPulseRadius
NUMBER_COLLS = [("Spacing", "spacing", "MonoPulseSpacing"), ("Radius", "radius", "MonoPulseRadius"),
                ("Elevation", "elevation", "MonoPulseElevation"), ("Icon", "icon", "MonoPulseIcons"),
                ("Border", "border", "MonoPulseBorder")]
SPACE_AT = {v: k for k, v in SPACING.items()}
RADIUS_AT = {v: k for k, v in RADII.items()}
VARS = {}  # "Spacing/lg" -> variable id, while online
TOKENS = os.path.join(HERE, ".tokens.json")
STATS = {"on": 0, "off": 0, "off_values": {}}


def bind_cmds(target, props):
    """variable.bind steps for gap / padding / corner radius values that sit on the token scales."""
    if not VARS:
        return []
    out = []

    def bind(field, value, coll, table):
        if not isinstance(value, (int, float)) or value == 0:
            return
        name = table.get(value)
        if name is None:
            STATS["off"] += 1
            key = f"{coll}:{value:g}"
            STATS["off_values"][key] = STATS["off_values"].get(key, 0) + 1
            return
        STATS["on"] += 1
        out.append({"command": "variable.bind", "params": {"ids": [target], "field": field,
                                                           "variable": VARS[f"{coll}/{name}"]}})
    if "gap" in props:
        bind("gap", props["gap"], "Spacing", SPACE_AT)
    pad = props.get("padding")
    if pad is not None:
        sides = [pad] * 4 if isinstance(pad, (int, float)) else pad
        for field, v in zip(("paddingTop", "paddingRight", "paddingBottom", "paddingLeft"), sides):
            bind(field, v, "Spacing", SPACE_AT)
    cr = props.get("cornerRadius")
    if cr is not None:
        if isinstance(cr, list):
            for field, v in zip(("topLeftRadius", "topRightRadius", "bottomRightRadius", "bottomLeftRadius"), cr):
                bind(field, v, "Radius", RADIUS_AT)
        else:
            bind("cornerRadius", cr, "Radius", RADIUS_AT)
    return out


ALIGN = {"start": "min", "end": "max", "min": "min", "center": "center", "max": "max",
         "spaceBetween": "spaceBetween", "spaceAround": "spaceAround", "spaceEvenly": "spaceEvenly",
         "baseline": "baseline"}
RADIUS = RADII


def align(v):
    if v not in ALIGN:
        raise ValueError(f"unknown alignment {v!r}")
    return ALIGN[v]


def radius(v):
    v = RADIUS.get(v, v) if isinstance(v, str) else v
    if not (isinstance(v, (int, float)) or (isinstance(v, list) and len(v) == 4)):
        raise ValueError(f"radius must be n, [tl,tr,br,bl] or a MonoPulseRadius name, got {v!r}")
    return v


def frame_props(n, layout):
    p = {"fill": color(n.get("bg", "none")), "layout": layout,
         "gap": n.get("gap", 0), "padding": n.get("pad", 0),
         "mainAlign": align(n.get("main", "min")), "crossAlign": align(n.get("cross", "min"))}
    if "radius" in n:
        p["cornerRadius"] = radius(n["radius"])
    if "border" in n:
        p["stroke"] = color(n["border"])
        p["strokeWeight"] = n.get("borderW", 1)
        p["strokeAlign"] = "inside"
    if n.get("shadow"):
        p["effects"] = [{"type": "dropShadow", "color": "#00000040", "offset": [0, 2],
                         "radius": 8, "visible": True}]
    if n.get("clip"):
        p["clip"] = True
    if n.get("abs"):
        p.update(absolute=True, x=n["abs"][0], y=n["abs"][1])
    if n.get("wrap"):
        p["wrap"] = True
        p["crossGap"] = n.get("gap", 0)
    if "opacity" in n:
        p["opacity"] = n["opacity"]
    return p


def emit(e, n, parent, pdir):
    if isinstance(n, str):
        n = {"t": "text", "v": n}
    t = n.get("t", "col")
    if t == "pattern":
        cname = {"song_card": "SongCard", "setlist_card": "SetlistCard",
                 "member_card": "MemberCard"}.get(n.get("name"))
        if cname is None:
            raise ValueError(f"unknown pattern {n.get('name')!r}")
        return use(e, cname, n, parent, pdir) if ONLINE and cname in LIB else m_pattern(e, n, parent, pdir)
    cname = TYPE2COMP.get(t)
    if cname and t not in getattr(e, "drawing", ()) and (cname in LIB or not ONLINE):
        try:
            return use(e, cname, n, parent, pdir)
        except Unsupported:
            pass
    fn = MACROS.get(t)
    if fn is None:
        raise ValueError(f"unknown node type {t!r} in {json.dumps(n)[:200]}")
    return fn(e, n, parent, pdir)


def children(e, kids, parent, pdir):
    for k in kids or []:
        emit(e, k, parent, pdir)


def m_pattern(e, n, parent, pdir):
    name = n["name"]
    subtitle_color = "textSecondary" if name == "song_card" else "textTertiary"
    return m_container("v")(e, {"name": n.get("component", name), "pad": 12, "gap": 2,
        "w": n.get("w", "fill" if pdir == "v" else "hug"),
        "c": [{"t": "text", "v": n.get("title", ""), "style": "titleMedium", "maxLines": 1,
               "name": "Title"},
              {"t": "text", "v": n.get("subtitle", ""), "style": "bodySmall", "color": subtitle_color,
               "name": "Subtitle"},
              {"t": "text", "v": n.get("meta", ""), "style": "bodySmall", "color": subtitle_color,
               "name": "Meta"}]}, parent, pdir)


def i_pattern(n, pdir):
    return dict(p={"Title": str(n.get("title", "")), "Subtitle": str(n.get("subtitle", "")),
                   "Meta": str(n.get("meta", ""))}, w=fill_w(pdir))


def m_container(layout):
    def f(e, n, parent, pdir):
        p = frame_props(n, "horizontal" if layout == "h" else "vertical")
        p.update(size_props(n, pdir))
        if "w" not in n:
            p["sizingH"] = "fill" if pdir == "v" else "hug"
        if "h" not in n:
            p["sizingV"] = "hug"
        r = e.create("frame", parent, n.get("name", "Row" if layout == "h" else "Column"), p)
        children(e, n.get("c"), r, layout)
        return r
    return f


def m_text(e, n, parent, pdir):
    style = n.get("style", "bodyMedium")
    p, _ = text_props(style, n.get("color", "textPrimary"))
    if isinstance(n.get("size"), (int, float)):  # a bound text style wins over fontSize: unbind it
        fam, sty = TYPE[style][:2]
        p.pop("textStyle")
        p.update(fontFamily=fam, fontStyle=sty, fontSize=n["size"])
    if n.get("align"):
        p["textAlign"] = n["align"]
    if n.get("weight"):
        p["fontStyle"] = n["weight"]
    if n.get("maxLines"):
        p["maxLines"] = n["maxLines"]
    if "opacity" in n:
        p["opacity"] = n["opacity"]
    w = n.get("w", "fill" if pdir == "v" else "hug")
    if w == "hug":
        p["textAutoResize"] = "widthAndHeight"
    else:
        p["textAutoResize"] = "height"
        p.update(size_props({"w": w}, pdir))
    if "h" in n:
        p.update(textAutoResize="none", **size_props({"h": n["h"]}, pdir))
    return e.create("text", parent, n.get("name"), p, text=str(n.get("v", "")))


def m_icon(e, n, parent, pdir):
    name = n.get("v") or n.get("name")
    cp = ICONS.get(name)
    if cp is None:
        raise ValueError(f"unknown Material icon {name!r}")
    size = n.get("size", 24)
    p = {"fontFamily": "Material Icons", "fontStyle": "Regular", "fontSize": size,
         "lineHeight": size, "fill": color(n.get("color", "textPrimary")),
         "textAutoResize": "widthAndHeight"}
    if "opacity" in n:
        p["opacity"] = n["opacity"]
    return e.create("text", parent, n.get("layer", f"icon/{name}"), p, text=chr(cp))


def m_box(e, n, parent, pdir):
    p = {"fill": color(n.get("bg", "surfaceRaised"))}
    if "radius" in n:
        p["cornerRadius"] = radius(n["radius"])
    if "border" in n:
        p.update(stroke=color(n["border"]), strokeWeight=n.get("borderW", 1), strokeAlign="inside")
    p.update(size_props({"w": n.get("w", 40), "h": n.get("h", 40)}, pdir))
    if n.get("abs"):
        p.update(absolute=True, x=n["abs"][0], y=n["abs"][1])
    typ = "ellipse" if n.get("circle") else "rectangle"
    return e.create(typ, parent, n.get("name", "Box"), p)


def m_spacer(e, n, parent, pdir):
    if isinstance(n.get("size"), (int, float)):  # anything else ("flex") = Spacer()
        k = "h" if pdir == "v" else "w"
        return m_box(e, {"bg": "none", k: n["size"], ("w" if k == "h" else "h"): 1,
                         "name": "Spacer"}, parent, pdir)
    p = {"fill": "none", "sizingH" if pdir == "h" else "sizingV": "fill"}
    p["sizingV" if pdir == "h" else "sizingH"] = "fixed"
    return e.create("frame", parent, "Spacer", p, w=1, h=1)


def m_divider(e, n, parent, pdir):
    p = {"fill": color(n.get("color", "borderSubtle"))}
    if pdir == "h":
        p.update(sizingV="fill", width=1, sizingH="fixed")
    else:
        p.update(sizingH="fill", height=1, sizingV="fixed")
    return e.create("rectangle", parent, "Divider", p)


def m_card(e, n, parent, pdir):
    """AppCard: padded surface around a Content frame (the component's slot)."""
    d = {"bg": "surface", "border": "borderSubtle", "radius": 7, "pad": 16}
    d.update({k: n[k] for k in ("bg", "border", "borderW", "radius", "pad", "shadow", "opacity", "w", "h",
                                "clip") if k in n})
    d["name"] = n.get("name", "Card")
    lay = "h" if n.get("dir") == "h" else "v"
    content = {"t": "row" if lay == "h" else "col", "name": "Content", "w": "fill",
               "gap": n.get("gap", 8), "c": n.get("c", [])}
    for k in ("main", "cross", "wrap"):
        if k in n:
            content[k] = n[k]
    d["c"] = [content]
    return m_container("v")(e, d, parent, pdir)


BUTTON_LOOK = {  # variant: (bg, fg, border) -- CustomButton / theme button styles
    "primary": ("accentOrange", "charcoal", "charcoal"),
    "secondary": ("white", "charcoal", "charcoal"),       # CustomButton secondary: white ElevatedButton
    "outline": ("none", "textPrimary", "borderDefault"),  # OutlinedButton
    "text": ("none", "textPrimary", None),
    "tonal": ("textSecondary", "black", None),  # FilledButton.tonal: secondaryContainer / onSecondaryContainer
    "danger": ("error", "charcoal", "charcoal"),
    "fab": ("white", "charcoal", "charcoal"),
}
BUTTON_SIZE = {"small": ([8, 12, 8, 12], 16), "medium": ([16, 20, 16, 20], 18), "large": ([16, 32, 16, 32], 20)}
SPEC_KIND = {"primary": "primary", "secondary": "outline", "outline": "outline", "text": "text",
             "tonal": "tonal", "danger": "danger", "white": "secondary"}  # spec `kind` -> variant


def m_button(e, n, parent, pdir):
    kind = n.get("kind", "primary")
    variant = "fab" if kind == "fab" else SPEC_KIND.get(kind)
    if variant is None:
        raise ValueError(f"button kind {kind!r}")
    bg, fg, border = BUTTON_LOOK[variant]
    size = n.get("size") or ("small" if n.get("small") else "medium")
    pad, isz = ([16, 16, 16, 16], 24) if variant == "fab" else BUTTON_SIZE[size]
    d = {"t": "row", "name": n.get("rootName", f"Button/{variant}"), "bg": bg, "radius": {"fab": 6}.get(variant, 5),
         "pad": pad, "gap": 8, "main": "center", "cross": "center", "w": n.get("w", "hug")}
    if border:
        d.update(border=border, borderW=1.2 if variant in ("primary", "secondary", "danger", "fab") else 1)
    if variant in ("primary", "secondary", "danger", "fab"):
        d["shadow"] = True
    state = n.get("state", "default")
    if state == "disabled":
        d["opacity"] = .38
    loading = state == "loading"
    ink_opacity = 0 if loading else 1
    kids = []
    if n.get("icon"):
        kids.append({"t": "icon", "v": n["icon"], "size": isz, "color": fg, "layer": "Icon",
                     "opacity": ink_opacity})
    if n.get("v"):
        kids.append({"t": "text", "v": n["v"], "style": "labelLarge", "color": fg, "w": "hug",
                     "name": n.get("labelName", "Label"), "opacity": ink_opacity})
    spinner = {"t": "icon", "v": "autorenew", "size": 18, "color": fg, "layer": "Loading",
               "opacity": int(loading)}
    if variant == "fab":
        return m_container("h")(e, dict(d, c=[spinner] if loading else kids), parent, pdir)
    root = m_container("h")(e, d, parent, pdir)
    slot = e.create("frame", root, "Content", {"fill": "none", "layout": "grid", "gridColumns": 1, "gridRows": 1,
                    "columnTracks": ["auto"], "rowTracks": ["auto"], "sizingH": "hug", "sizingV": "hug"})
    # Both layers contribute to the same cell's size while their opacity swaps.
    cell = {"gridColumn": 0, "gridRow": 0, "gridAlignH": "center", "gridAlignV": "center"}
    for draw, content in (
        (m_container("h"), {"name": "Label and icon", "gap": 8, "cross": "center", "c": kids}),
        (m_icon, spinner),
    ):
        start = len(e.cmds)
        draw(e, content, slot, "h")
        e.cmds[start]["params"]["props"].update(cell)
    return root


def m_chip(e, n, parent, pdir):
    sel = n.get("sel")
    d = {"name": "Chip", "bg": "stone" if sel else "surfaceRaised", "border": "borderDefault",
         "radius": 10, "pad": [6, 12, 6, 12], "gap": 4, "cross": "center", "w": "hug"}
    if n.get("state") == "disabled":
        d["opacity"] = .38
    fg = "charcoal" if sel else "textPrimary"
    kids = [{"t": "icon", "v": n["icon"], "size": 16, "color": fg, "layer": "Icon"}] if n.get("icon") else []
    kids.append({"t": "text", "v": n.get("v", ""), "style": "labelMedium", "color": fg, "w": "hug",
                 "name": "Label"})
    d["c"] = kids
    return m_container("h")(e, d, parent, pdir)


def m_input(e, n, parent, pdir):
    kids = []
    if n.get("label"):
        kids.append({"t": "text", "v": n["label"], "style": "labelMedium", "color": "textSecondary",
                     "name": "Label"})
    state = n.get("state", "filled" if n.get("v") else "hint")
    field = {"name": "Field", "bg": "white", "border": "accentOrange" if state == "focus" else "error" if state == "error" else "borderDefault",
             "borderW": 2, "radius": 10,
             "pad": [14, 14, 14, 14], "gap": 10, "cross": "min" if n.get("lines") else "center",
             "c": []}
    if n.get("lines"):
        field["h"] = 24 * n["lines"] + 28
    if n.get("icon"):
        field["c"].append({"t": "icon", "v": n["icon"], "size": 20, "color": "#62625A", "layer": "Icon"})
    val = n.get("v")
    field["c"].append({"t": "text", "v": val or n.get("hint", ""), "style": "bodyLarge",
                       "color": "#1E1E1C" if val else "#62625A", "w": "fill", "name": "Value",
                       "maxLines": n.get("lines") or 1})
    if n.get("trail"):
        field["c"].append({"t": "icon", "v": n["trail"], "size": 20, "color": "#62625A", "layer": "Trail"})
    kids.append(dict(field, t="row"))
    kids.append({"t": "text", "name": "Helper", "v": n.get("helper", "Please check this field"),
                 "style": "bodySmall", "color": "error", "maxLines": 1,
                 "opacity": 1 if state == "error" else 0})
    return m_container("v")(e, {"name": n.get("name", "Input"), "gap": 6, "c": kids,
                                "opacity": .38 if state == "disabled" else 1,
                                "w": n.get("w", "fill" if pdir == "v" else "hug")}, parent, pdir)


def m_avatar(e, n, parent, pdir):
    s = n.get("size", 40)
    d = {"name": "Avatar", "bg": n.get("bg", "surfaceOverlay"), "radius": s / 2, "w": s, "h": s,
         "main": "center", "cross": "center",
         "c": [{"t": "icon", "v": n["icon"], "size": s * 0.55, "color": n.get("color", "textPrimary"),
                "layer": "Icon"}
               if n.get("icon") else
               {"t": "text", "v": n.get("v", "?"), "style": "labelLarge", "w": "hug",
                "color": n.get("color", "textPrimary"), "name": "Initials"}]}
    return m_container("h")(e, d, parent, pdir)


def lead_node(x):
    if isinstance(x, dict):
        return x
    if x in ICONS:
        return {"t": "icon", "v": x, "color": "textSecondary"}
    return {"t": "avatar", "v": x}


def m_tile(e, n, parent, pdir):
    trail = n.get("trail")
    trail = trail if isinstance(trail, list) else ([trail] if trail else [])
    kids = []
    if n.get("lead") or n.get("_slots"):
        kids.append({"t": "row", "name": "Leading", "cross": "center",
                     "c": [lead_node(n["lead"])] if n.get("lead") else []})
    body = {"t": "col", "name": "Text", "gap": 2, "w": "fill",
            "c": [{"t": "text", "v": n.get("title", ""), "style": n.get("titleStyle", "bodyLarge"),
                   "maxLines": 1, "name": "Title"}]}
    if n.get("sub"):
        body["c"].append({"t": "text", "v": n["sub"], "style": "bodySmall", "color": "textTertiary",
                          "maxLines": 2, "name": "Subtitle"})
    kids.append(body)
    if trail or n.get("_slots"):
        kids.append({"t": "row", "name": "Trailing", "cross": "center", "gap": 8,
                     "c": [trail_node(t) for t in trail]})
    if n.get("_switch") is not None:
        kids.append({"t": "switch", "on": n["_switch"], "name": "Switch"})
    d = {"name": n.get("name", "ListTile"), "pad": n.get("pad", [12, 16, 12, 16]), "gap": 16,
         "cross": "center", "bg": n.get("bg", "none"), "c": kids, "w": n.get("w", "fill" if pdir == "v" else "hug")}
    for k in ("border", "radius"):
        if k in n:
            d[k] = n[k]
    if n.get("selected"):
        d["bg"] = "accentOrange10"
    return m_container("h")(e, d, parent, pdir)


def trail_node(tr):
    if isinstance(tr, dict):
        return tr
    if tr in ICONS:
        return {"t": "icon", "v": tr, "size": 20, "color": "textTertiary"}
    return {"t": "text", "v": tr, "style": "labelSmall", "color": "textTertiary", "w": "hug"}


def m_switch(e, n, parent, pdir):
    on = n.get("on", True)
    d = {"name": "Switch", "bg": "successGreen" if on else "fog", "radius": 16, "w": 52, "h": 32,
         "pad": 4, "main": "max" if on else "min", "cross": "center",
         "c": [{"t": "box", "circle": True, "bg": "white", "w": 24, "h": 24, "name": "Thumb"}]}
    return m_container("h")(e, d, parent, pdir)


def m_checkbox(e, n, parent, pdir):
    on = n.get("on", False)
    return m_container("h")(e, {"name": "Checkbox", "bg": "charcoal" if on else "none",
                                "border": "borderStrong", "borderW": 2, "radius": 2, "w": 20, "h": 20,
                                "main": "center", "cross": "center",
                                "c": [{"t": "icon", "v": "check", "size": 16, "color": "white", "layer": "Check"}] if on else []},
                            parent, pdir)


def m_switchrow(e, n, parent, pdir):
    t = {"title": n.get("title"), "sub": n.get("sub"), "lead": n.get("lead"), "_switch": n.get("on", True),
         "pad": n.get("pad", [8, 16, 8, 16]), "name": n.get("name", "SwitchRow"), "w": n.get("w"),
         "_slots": n.get("_slots")}
    return m_tile(e, {k: v for k, v in t.items() if v is not None}, parent, pdir)


def m_tabs(e, n, parent, pdir):
    items, sel = n.get("items", []), n.get("sel", 0)
    kids = [{"t": "tab", "v": it, "sel": i == sel} for i, it in enumerate(items)]
    return m_container("h")(e, {"name": "Tabs", "c": kids, "border": "borderSubtle"}, parent, pdir)


def m_tab(e, n, parent, pdir):
    on = n.get("sel")
    return m_container("v")(e, {
        "name": f"Tab/{n.get('v', '')}", "w": n.get("w", "fill"), "cross": "center", "gap": 8,
        "pad": [12, 4, 0, 4],
        "c": [{"t": "text", "v": n.get("v", ""), "style": "labelLarge", "align": "center", "name": "Label",
               "color": "accentOrange" if on else "textSecondary"},
              {"t": "box", "bg": "accentOrange" if on else "none", "w": "fill", "h": 3, "name": "Indicator"}]},
        parent, pdir)


def m_segmented(e, n, parent, pdir):
    items, sel = n.get("items", []), n.get("sel", 0)
    icons = n.get("icons") or []
    kids = [{"t": "segment", "v": it, "sel": i == sel, "icon": icons[i] if i < len(icons) else None}
            for i, it in enumerate(items)]
    d = {"name": "Segmented", "bg": "surfaceRaised", "radius": 10, "pad": 3, "gap": 2,
         "border": "borderSubtle", "c": kids, "w": n.get("w", "fill" if pdir == "v" else "hug")}
    return m_container("h")(e, d, parent, pdir)


def m_segment(e, n, parent, pdir):
    on = n.get("sel")
    return m_container("h")(e, {
        "w": n.get("w", "fill"), "main": "center", "cross": "center", "pad": [10, 8, 10, 8],
        "radius": 8, "bg": "stone" if on else "none", "name": f"Segment/{n.get('v', '')}",
        "gap": 8,
        "c": ([{"t": "icon", "v": n["icon"], "size": 18, "color": "charcoal" if on else "textSecondary"}]
              if n.get("icon") else []) +
             [{"t": "text", "v": n.get("v", ""), "style": "labelMedium", "w": "hug", "name": "Label",
               "color": "charcoal" if on else "textSecondary"}]}, parent, pdir)


def m_slider(e, n, parent, pdir):
    v = max(0.0, min(1.0, n.get("value", 0.5)))
    track_w = n.get("trackW", 300)
    d = {"name": "Slider", "h": 24, "cross": "center", "w": n.get("w", "fill"),
         "c": [{"t": "box", "bg": "accentOrange", "w": round(track_w * v), "h": 4, "radius": 2, "name": "Active"},
               {"t": "box", "circle": True, "bg": "accentOrange", "w": 18, "h": 18, "name": "Thumb"},
               {"t": "box", "bg": "borderDefault", "w": "fill", "h": 4, "radius": 2, "name": "Track"}]}
    return m_container("h")(e, d, parent, pdir)


def m_progress(e, n, parent, pdir):
    v = max(0.0, min(1.0, n.get("value", 0.5)))
    d = {"name": "Progress", "bg": "surfaceOverlay", "radius": 3, "h": 6, "w": "fill",
         "c": [{"t": "box", "bg": n.get("color", "accentOrange"), "w": round(n.get("trackW", 360) * v),
                "h": 6, "radius": 3, "name": "Fill"}]}
    return m_container("h")(e, d, parent, pdir)


def m_section(e, n, parent, pdir):
    """SectionHeader (lib/widgets/section_header.dart): title or quiet label + optional action."""
    label = n.get("kind") == "label"
    kids = [{"t": "text", "v": n.get("v", ""), "style": n.get("style", "labelMedium" if label else "titleMedium"),
             "color": n.get("color", "textSecondary" if label else "textPrimary"), "w": "fill", "name": "Title"}]
    if "style" not in n:
        kids[0].update(h=24, maxLines=1)
    if n.get("action"):
        kids.append({"t": "text", "v": n["action"], "style": "labelMedium", "color": "accentOrange", "w": "hug",
                     "name": "Action"})
    return m_container("h")(e, {"name": "SectionHeader", "pad": n.get("pad", [16, 16, 8, 16]),
                                "cross": "center", "c": kids}, parent, pdir)


def m_iconbtn(e, n, parent, pdir):
    d = {"name": "IconButton", "w": 48, "h": 48, "main": "center", "cross": "center",
         "bg": n.get("bg", "none"), "radius": n.get("radius", 24),
         "c": [{"t": "icon", "v": n.get("v"), "size": n.get("size", 24),
                "color": n.get("color", "textPrimary"), "layer": "Icon"}]}
    if n.get("border"):
        d["border"] = n["border"]
    return m_container("h")(e, d, parent, pdir)


def m_badge(e, n, parent, pdir):
    """AppBadge (lib/widgets/app_badge.dart): 10% tint pill, 16 px icon, bodySmall label."""
    tint = n.get("color", "accentOrange")
    d = {"name": "Badge", "bg": n.get("bg", "accentOrange10"), "radius": 20, "pad": [6, 12, 6, 12],
         "cross": "center", "gap": 6, "w": "hug",
         "c": ([{"t": "icon", "v": n["icon"], "size": 16, "color": tint, "layer": "Icon"}] if n.get("icon") else []) +
              [{"t": "text", "v": n.get("v", ""), "style": "bodySmall",
                "color": "textPrimary" if n.get("outlined") else tint, "w": "hug", "name": "Label"}]}
    if n.get("outlined"):
        d["border"] = tint
    return m_container("h")(e, d, parent, pdir)


def m_appbar(e, n, parent, pdir):
    kids = []
    if n.get("back", True) or n.get("leading"):
        kids.append({"t": "iconbtn", "v": n.get("leading", "arrow_back"), "name": "Leading"})
    title = {"t": "col", "name": "Heading", "w": "fill", "gap": 0, "pad": [0, 0, 0, 0 if kids else 12],
             "c": [{"t": "text", "v": n.get("v", ""), "style": n.get("style", "headlineLarge"), "maxLines": 1,
                    "name": "Title"}]}
    if n.get("sub") or n.get("_slots"):
        title["c"].append({"t": "text", "v": n.get("sub", "Subtitle"), "style": "bodySmall",
                           "color": "textTertiary", "name": "Subtitle"})
    kids.append(title)
    acts = [a if isinstance(a, dict) else {"t": "iconbtn", "v": a} for a in n.get("actions", [])]
    if acts or n.get("_slots"):
        kids.append({"t": "row", "name": "Actions", "gap": 4, "cross": "center", "c": acts})
    return m_container("h")(e, {"name": "AppBar", "bg": "black", "h": 64, "pad": [8, 4, 8, 4],
                                "cross": "center", "gap": 4, "c": kids, "w": "fill"}, parent, pdir)


NAV_TABS = [("Home", "home"), ("Songs", "music_note"), ("Bands", "groups"),
            ("Setlists", "queue_music"), ("More", "more_horiz")]


def nav_icon(icon, on):
    return icon if on or icon + "_outlined" not in ICONS else icon + "_outlined"


def m_bottomnav(e, n, parent, pdir):
    sel = n.get("sel")
    kids = [{"t": "navitem", "v": label, "icon": nav_icon(icon, label == sel), "sel": label == sel,
             "name": label} for label, icon in NAV_TABS]
    return m_container("h")(e, {"name": "BottomNav", "bg": "black", "border": "borderSubtle",
                                "pad": [8, 8, 8, 8], "c": kids, "w": "fill"}, parent, pdir)


def m_navitem(e, n, parent, pdir):
    on = n.get("sel")
    c = "accentOrange" if on else "textSecondary"
    return m_container("v")(e, {
        "name": f"NavItem/{n.get('v', '')}", "w": n.get("w", "fill"), "cross": "center", "gap": 4,
        "pad": [4, 0, 4, 0],
        "c": [{"t": "icon", "v": n.get("icon", "home"), "size": 22, "color": c, "layer": "Icon"},
              {"t": "row", "name": "Pill", "bg": "accentOrange15" if on else "none", "radius": 20,
               "pad": [2, 8, 2, 8], "w": "hug",
               "c": [{"t": "text", "v": n.get("v", ""), "style": "labelSmall", "color": c, "w": "hug",
                      "name": "Label"}]}]}, parent, pdir)


def m_actionbar(e, n, parent, pdir):
    """AppBottomBar.actions: [Back] [title | primary action] [Menu], flex 1:2:1 (99/198/99 at 412)."""
    center = []
    if n.get("title") or n.get("_slots"):
        center.append({"t": "text", "v": n.get("title", "Title"), "style": "labelLarge", "align": "center",
                       "maxLines": 1, "w": "fill", "name": "Title"})
    if n.get("primary") or n.get("_slots"):
        center.append({"t": "button", "v": n.get("primary", "Save"), "icon": n.get("icon"), "name": "Primary"})
    kids = [{"t": "navitem", "v": "Back", "icon": "arrow_back", "w": 99, "name": "Back"},
            {"t": "row", "name": "Center", "w": 198, "main": "center", "cross": "center", "c": center}]
    if n.get("menu", True) or n.get("_slots"):
        kids.append({"t": "navitem", "v": "Menu", "icon": "more_horiz", "w": 99, "name": "Menu"})
    return m_container("h")(e, {"name": "ActionBar", "bg": "black", "border": "borderSubtle",
                                "pad": [8, 8, 8, 8], "cross": "center", "c": kids, "w": "fill"},
                            parent, pdir)


def m_fab(e, n, parent, pdir):
    return m_button(e, dict(n, kind="fab"), parent, pdir)


def m_sheet(e, n, parent, pdir):
    """Bottom sheet (docked) or floating panel with a reserved handle slot."""
    docked = n.get("bottom", True)
    kids = [{"t": "row", "name": "Handle", "main": "center", "opacity": int(docked),
             "c": [{"t": "box", "bg": "borderStrong", "w": 36, "h": 4, "radius": 2, "name": "Grabber"}]}]
    kids.append({"t": "col", "name": "Content", "gap": n.get("gap", 8), "c": n.get("c", [])})
    d = {"name": n.get("name", "Sheet"), "bg": "surfaceRaised", "radius": [16, 16, 0, 0] if docked else 16,
         "pad": n.get("pad", [12, 16, 24, 16]), "gap": 8, "c": kids, "border": "borderSubtle",
         "w": n.get("w", "fill" if pdir == "v" else "hug")}
    return m_container("v")(e, d, parent, pdir)


def m_dialog(e, n, parent, pdir):
    """AlertDialog: icon, title, Content frame, right-aligned Actions frame (both slots)."""
    kids = []
    if n.get("icon") or n.get("_slots"):
        kids.append({"t": "icon", "v": n.get("icon", "info_outline"), "size": 24,
                     "color": n.get("iconColor", "textSecondary"), "layer": "Icon"})
    if n.get("title") or n.get("_slots"):
        kids.append({"t": "text", "v": n.get("title", "Title"), "style": "headlineMedium", "name": "Title"})
    if n.get("c") or n.get("_slots"):
        kids.append({"t": "col", "name": "Content", "gap": 16, "c": n.get("c", [])})
    if n.get("actions") or n.get("_slots"):
        kids.append({"t": "row", "name": "Actions", "main": "max", "gap": 8, "pad": [8, 0, 0, 0],
                     "c": n.get("actions", [])})
    d = {"name": n.get("name", "Dialog"), "bg": "surfaceRaised", "radius": 16, "pad": 24, "gap": 16,
         "border": "borderSubtle", "shadow": True, "c": kids, "w": n.get("w", "fill")}
    return m_container("v")(e, d, parent, pdir)


def m_statusbar(e, n, parent, pdir):
    return m_container("h")(e, {
        "name": "StatusBar", "h": 28, "pad": [4, 20, 4, 20], "cross": "center", "bg": n.get("bg", "black"),
        "w": "fill",
        "c": [{"t": "text", "v": "9:41", "style": "labelSmall", "w": "hug", "name": "Time"}, {"t": "spacer"},
              {"t": "icon", "v": "signal_cellular_alt", "size": 14},
              {"t": "icon", "v": "wifi", "size": 14}, {"t": "icon", "v": "battery_full", "size": 14}]},
        parent, pdir)


def m_raw(e, n, parent, pdir):
    p = dict(n.get("props", {}))
    for k in ("fill", "stroke"):
        if k in p:
            p[k] = color(p[k])
    p.update(size_props(n, pdir))
    return e.create(n.get("type", "rectangle"), parent, n.get("name"), p, text=n.get("v"),
                    w=n.get("width"), h=n.get("height"))


def pad_progress(n):
    value = n.get("progress", 0)
    if type(value) not in (int, float) or not 0 <= value <= 1:
        raise ValueError("pad progress must be between 0 and 1")
    return {"width": max(1, n.get("w", 180) * value), "visible": value > 0}


def m_pad(e, n, parent, pdir):
    state = n.get("state", "idle")
    playing = state == "playing"
    fg = "charcoal" if playing else "textPrimary"
    border = {"selected": "textPrimary", "queued": "accentOrange"}.get(state)
    props = frame_props({"bg": "accentOrange" if playing else PAD_SURFACES[e.mode], "radius": 8,
                         "cross": "center", "gap": 8, "pad": [0, 8, 0, 8 if playing or border else 0], "clip": True,
                         "opacity": .38 if state == "disabled" else 1,
                         **({"border": border, "borderW": 3} if border else {})}, "horizontal")
    w = n.get("w", 180)
    props.update(size_props({"w": w, "h": 80}, pdir))
    r = e.create("frame", parent, n.get("name", "Pad"), props)
    if playing:
        m_icon(e, {"v": "play_arrow", "size": 20, "color": fg}, r, "h")
    else:
        stripe = {"w": 6, "h": "fill", "bg": n.get("color", "section1"), "name": "Stripe"}
        if border:
            stripe["h"] = 64
        m_box(e, stripe, r, "h")
    if n.get("letter"):
        token = n.get("color", "section1")
        badge = m_container("h")(e, {"name": "Letter badge", "w": 24, "h": 24, "radius": 8,
                                    "bg": token, "main": "center", "cross": "center", "clip": True}, r, "h")
        if token == "section1":
            e.create("rectangle", badge, "Contrast tint", {"absolute": True, "x": 0, "y": 0,
                     "width": 24, "height": 24, "fill": color("charcoal"), "opacity": BADGE_SECTION1_SHADE})
        m_text(e, {"v": n["letter"], "style": "labelSmall",
                   "color": "white" if token in BADGE_WHITE_SECTIONS else "charcoal"}, badge, "h")
    kids = [{"t": "text", "name": "Label", "v": n.get("label", ""), "style": "labelLarge",
             "color": fg, "maxLines": 1},
            {"t": "text", "name": "Subtitle", "v": n.get("sub", ""), "style": "bodySmall",
             "color": fg if playing else "textSecondary", "maxLines": 1}]
    if state == "queued":
        kids.append({"t": "text", "v": "next", "style": "labelSmall"})
    m_container("v")(e, {"w": "fill", "c": kids}, r, "h")
    if playing:
        e.create("rectangle", r, "Loop progress", {"fill": color("charcoal"), "absolute": True,
                                                  "x": 0, "y": 76, "height": 4, **pad_progress(n)})
    return r


def m_secblock(e, n, parent, pdir):
    part = n["t"] == "partblock"
    w = n.get("w", 80 if part else 112)
    state = n.get("state", "confirmed")
    border = {"selected": "textPrimary", "playing": "accentOrange"}.get(state, "borderStrong")
    props = frame_props({"bg": "surface", "radius": 5, "clip": True, "border": border,
                         "borderW": 3 if state in ("selected", "playing") else 1,
                         "main": "center", "pad": [0, 4, 0, 4]}, "vertical")
    props.update(size_props({"w": w, "h": 48}, pdir))
    if state == "candidate":
        props["dashes"] = [4, 3]
    r = e.create("frame", parent, n.get("name", "PartBlock" if part else "SectionBlock"), props)
    tint = color(n.get("color", "section1"))
    e.create("rectangle", r, "Tint", {"absolute": True, "x": 3, "y": 3, "height": 42,
                                     "width": max(1, w - 6), "fill": tint, "opacity": .2})
    if state == "playing":
        e.create("rectangle", r, "Playing tint", {"absolute": True, "x": 3, "y": 3, "height": 42,
                                                 "width": max(1, w - 6), "fill": color("charcoal"), "opacity": .12})
    if part:
        for layer, value, style in (("Letter", n.get("letter", ""), "labelSmall"),
                                    ("Label", block_label(n), "bodySmall")):
            m_text(e, {"name": layer, "v": value, "style": style, "maxLines": 1}, r, "v")
    else:
        m_text(e, {"name": "Label", "v": block_label(n), "style": "bodySmall", "maxLines": 1}, r, "v")
    return r


def block_label(n):
    if n["t"] == "partblock":
        bars = n.get("bars", 4)
        return f"{bars} bar" if bars == 1 else f"{bars} bars"
    return n.get("letter", "")


def m_wave(e, n, parent, pdir):
    height = n.get("h", 72)
    rng = random.Random(7)
    bars = [{"t": "box", "name": f"Wave {i + 1}", "w": 2,
             "h": max(3, round(height * rng.uniform(.12, .9))), "bg": "textSecondary"}
            for i in range(64)]
    return m_container("h")(e, {"name": n.get("name", "Waveform"), "w": n.get("w", "fill"),
                                 "h": height, "gap": 2, "cross": "center", "main": "spaceBetween",
                                 "bg": n.get("bg", "surfaceRaised"), "radius": n.get("radius", 8), "c": bars},
                             parent, pdir)


def timeline_marker(e, n, parent, pdir, name, ink, tip, dashes=False):
    props = frame_props({"cross": "center"}, "vertical")
    props.update(size_props({"w": 16, "h": n.get("h", 72)}, pdir))
    r = e.create("frame", parent, n.get("name", name), props)
    m_icon(e, {"v": tip, "size": 16, "color": ink}, r, "v")
    stem = {"sizingV": "fill", "width": 2, "fill": color(ink)}
    if dashes:
        stem.update(fill="none", width=3, stroke=color(ink), strokeWeight=1,
                    strokeAlign="inside", dashes=[3, 3])
    e.create("rectangle", r, "Stem", stem)
    return r


def m_boundary(e, n, parent, pdir):
    state = n.get("state", "confirmed")
    ink = "textPrimary" if state == "selected" else "borderStrong"
    return timeline_marker(e, n, parent, pdir, "Boundary", ink, "drag_indicator", state == "candidate")


def m_playhead(e, n, parent, pdir):
    return timeline_marker(e, n, parent, pdir, "Playhead", "accentOrange", "arrow_drop_down")


def minimap_sections(n):
    return [{"t": "box", "bg": s["color"], "w": s["w"], "h": 12} for s in n.get("sections", [])]


def minimap_viewport(n):
    total = sum(s["w"] for s in n.get("sections", []))
    x, w = n.get("viewport", [0, total])
    if x < 0 or w < 0 or x + w > total:
        raise ValueError("minimap viewport must fit within the section strip")
    return total, {"x": x, "width": max(1, w), "visible": w > 0}


def m_minimap(e, n, parent, pdir):
    total, viewport = minimap_viewport(n)
    r = m_container("h")(e, {"name": n.get("name", "Minimap"), "w": max(1, total), "h": 16,
                             "cross": "center", "c": [{"t": "row", "name": "Sections", "w": "fill",
                             "h": 12, "c": [] if n.get("_slots") else minimap_sections(n)}]}, parent, pdir)
    e.create("rectangle", r, "Viewport", {"absolute": True, "y": 0, "height": 16, "fill": "none",
                                          "stroke": color("textPrimary"), "strokeWeight": 2,
                                          "strokeAlign": "inside", **viewport})
    return r


def ruler_labels(n):
    return [{"t": "col", "w": "fill", "cross": "center", "gap": 2, "c": [
        {"t": "box", "w": 1, "h": 6, "bg": "borderStrong"},
        {"t": "text", "v": label, "w": "hug", "style": "caption", "color": "textSecondary"}]}
        for label in n.get("labels", [])]


def beatgrid_bars(n):
    beats, bars = n.get("beats", 4), n.get("bars", 1)
    if any(type(v) is not int or v < 1 for v in (beats, bars)):
        raise ValueError("beatgrid beats and bars must be positive integers")
    return [{"t": "row", "w": "fill", "border": "borderSubtle", "c": [
        {"t": "col", "w": "fill", "cross": "center", "gap": 4, "c": [
            {"t": "box", "w": 1, "h": 12 if beat == 1 else 6, "bg": "borderStrong"},
            {"t": "text", "v": beat, "w": "hug", "style": "caption",
             "color": "textPrimary" if beat == 1 else "textSecondary"}]}
        for beat in range(1, beats + 1)]} for _ in range(bars)]


def breadcrumb_items(n):
    kids = []
    items = n.get("items", [])
    for i, item in enumerate(items):
        if i:
            kids.append({"t": "icon", "v": "chevron_right", "size": 16, "color": "textSecondary"})
        kids.append({"t": "text", "v": item, "style": "labelMedium",
                     "color": "textPrimary" if i == len(items) - 1 else "textSecondary"})
    return kids


def transport_controls(n):
    playing = n.get("playing", False)
    speed = n.get("speed", 100)
    controls = [("pause" if playing else "play_arrow", "Pause" if playing else "Play", True),
                ("loop", "Loop", n.get("loop", False)),
                ("speed", f"{speed}%" if isinstance(speed, (int, float)) else speed, False),
                ("timer", "Count-in", n.get("countIn", False)),
                ("volume_up", "Click", n.get("click", False)),
                ("graphic_eq", "Drums", n.get("drums", False))]
    return [{"t": "col", "w": "fill", "h": 48, "cross": "center", "main": "center",
             "radius": 8, "bg": "accentOrange" if i == 0 else "surfaceRaised",
             **({"border": "textPrimary", "borderW": 2} if on and i else {}),
             "c": [{"t": "icon", "v": icon, "size": 20, "color": "charcoal" if i == 0 else "textPrimary"},
                   {"t": "text", "v": label, "w": "hug", "style": "caption",
                    "color": "charcoal" if i == 0 else "textPrimary"}]}
            for i, (icon, label, on) in enumerate(controls)]


def m_song_map_row(e, n, parent, pdir, name, layer, kids, **props):
    return m_container("v")(e, {"name": n.get("name", name), "w": n.get("w", "fill"),
                                "c": [{"t": "row", "name": layer, "w": "fill",
                                       "c": [] if n.get("_slots") else kids(n), **props}]}, parent, pdir)


def m_ruler(e, n, parent, pdir):
    return m_song_map_row(e, n, parent, pdir, "Ruler", "Labels", ruler_labels, h=26)


def m_beatgrid(e, n, parent, pdir):
    return m_song_map_row(e, n, parent, pdir, "BeatGrid", "Bars", beatgrid_bars, h=40, gap=2)


def m_breadcrumb(e, n, parent, pdir):
    return m_song_map_row(e, n, parent, pdir, "Breadcrumb", "Items", breadcrumb_items,
                          h=32, gap=4, cross="center")


def m_transport(e, n, parent, pdir):
    return m_song_map_row(e, n, parent, pdir, "Transport", "Controls", transport_controls,
                          h=64, gap=4, pad=8, bg="blackSurface", cross="center")


def timeline_content(n):
    return [{**n, "_timeline_content": True}]


def m_timeline(e, n, parent, pdir):
    zoom = n["t"] == "zoomwave"
    name = "ZoomWave" if zoom else "Overview"
    if not n.get("_timeline_content"):
        return m_song_map_row(e, n, parent, pdir, name, "Timeline", timeline_content)

    blocks = n["parts" if zoom else "sections"]
    counts = [block["bars"] for block in blocks]
    if not counts or any(type(count) is not int or count < 1 for count in counts):
        raise ValueError(f"{name} needs blocks with positive integer bar counts")
    total = sum(counts)
    edges = [0]
    for count in counts:
        edges.append(edges[-1] + count)
    edges = [edge / total for edge in edges]
    cuts = ([n["cut"]] if "cut" in n else []) if zoom else n.get("cuts", [])
    playheads = [n["playhead"]] if "playhead" in n else []
    markers = cuts + playheads
    if any(type(fraction) not in (int, float) or not 0 <= fraction <= 1 for fraction in markers):
        raise ValueError(f"{name} markers must be between 0 and 1")
    start_bar = n["startBar"] if zoom else 0
    if type(start_bar) is not int:
        raise ValueError("ZoomWave startBar must be an integer")
    bar_edges = [bar / total for bar in range(total + 1)] if zoom else []
    stops = sorted(set(edges + bar_edges + markers))
    columns = {x: i for i, x in enumerate(stops)}

    r = m_container("v")(e, {"name": "Strip", "w": "fill", "c": [
        {"t": "text", "name": "Title", "v": n["title"], "style": "labelMedium"}
    ] if zoom else []}, parent, pdir)
    wave_h, lane_h = (96, 40) if zoom else (64, 32)
    rows = [wave_h, lane_h] + ([26] if zoom else [])
    # Every layer uses these tracks, including markers that fall between bar boundaries.
    grid = e.create("frame", r, "Timeline grid", {"fill": "none", "layout": "grid", "sizingH": "fill",
                    "height": sum(rows), "sizingV": "fixed", "clip": True,
                    "gap": 0, "crossGap": 0,  # grid default gap is 10: it pushed the lane out of the clip
                    "gridColumns": len(stops) - 1, "gridRows": len(rows),
                    "columnTracks": [{"sizing": "fill", "value": (b - a) * total}
                                     for a, b in zip(stops, stops[1:])],
                    "rowTracks": rows})

    def place(draw, node, left, right, row, row_span=1, **props):
        start = len(e.cmds)
        draw(e, node, grid, "v")
        e.cmds[start]["params"]["props"].update(
            gridColumn=columns[left], gridColumnSpan=columns[right] - columns[left],
            gridRow=row, gridRowSpan=row_span, **props)

    def band(left, right, token, opacity=1):
        place(m_box, {"name": "Tint band" if opacity < 1 else "Wave and lane surface",
                      "w": "fill", "h": "fill", "bg": token}, left, right, 0, 2, opacity=opacity)

    band(0, 1, "surfaceRaised")
    if zoom:
        band(0, 1, n.get("color", "section1"), .25)
    else:
        for block, left, right in zip(blocks, edges, edges[1:]):
            band(left, right, block["color"], .25)
    place(m_wave, {"h": wave_h, "bg": "none", "radius": 0}, 0, 1, 0)

    for block, left, right in zip(blocks, edges, edges[1:]):
        state = block.get("state", "confirmed")
        if state not in ("confirmed", "selected", "playing", "candidate"):
            raise ValueError(f"{name}: unknown block state {state!r}")
        section_color = block.get("color", n.get("color", "section1"))
        labels = [{"t": "text", "v": block["letter"], "style": "labelSmall", "color": "textPrimary",
                   "align": "center", "maxLines": 1}]
        if zoom:
            labels.append({"t": "text", "v": block_label({"t": "partblock", **block}),
                           "style": "caption", "align": "center", "maxLines": 1})
        border = {"selected": "textPrimary", "playing": "accentOrange"}.get(state, "borderStrong")
        place(m_box, {"name": "Lane tint", "w": "fill", "h": "fill", "bg": section_color},
              left, right, 1, opacity=.35)
        place(m_container("v"), {"name": f"Block {block['letter']}", "w": "fill", "h": lane_h,
                                 "main": "center", "clip": True, "border": border,
                                 "borderW": 3 if state in ("selected", "playing") else 1,
                                 "bg": "none", "c": labels},
              left, right, 1, **({"dashes": [4, 3]} if state == "candidate" else {}))

    if zoom:
        for label, left, right in zip(ruler_labels({"labels": range(start_bar, start_bar + total)}),
                                      bar_edges, bar_edges[1:]):
            label["c"][1].update(style="labelSmall", v=str(label["c"][1]["v"]))
            place(m_container("v"), {**label, "bg": "none"}, left, right, 2)

    for i, x in enumerate(markers):
        cut = i < len(cuts)
        j = min(columns[x], len(stops) - 2)
        edge = "max" if x == 1 else "min"
        if cut:
            dashes = [{"t": "box", "w": 2, "h": min(4, wave_h + lane_h - y), "bg": "textPrimary"}
                      for y in range(0, wave_h + lane_h, 8)]
            place(m_container("v"), {"name": "New cut", "w": 2, "h": wave_h + lane_h, "gap": 4, "c": dashes},
                  stops[j], stops[j + 1], 0, 2, gridAlignH=edge)
        else:
            place(m_box, {"name": "Playhead", "w": 2, "h": wave_h + lane_h, "bg": "textPrimary"},
                  stops[j], stops[j + 1], 0, 2, gridAlignH=edge)
    if zoom and cuts and n.get("cutLabel"):
        x = cuts[0]
        left, right, edge = (x, 1, "min") if x < .5 else (0, x, "max")
        place(m_container("h"), {"name": "Cut label", "w": "hug", "bg": "surfaceRaised", "radius": 8,
                                 "pad": 4, "c": [{"t": "text", "v": n["cutLabel"], "style": "caption"}]},
              left, right, 0, gridAlignH=edge, gridAlignV="min")
    return r


def m_key(e, n, parent, pdir):
    lit = n.get("lit", False)
    fg = "charcoal" if lit else "textPrimary"
    kids = []
    if n.get("icon"):
        kids.append({"t": "icon", "v": n["icon"], "size": 16, "color": fg, "layer": "Icon"})
    kids.append({"t": "text", "v": n["v"], "name": "Label", "style": "labelMedium", "color": fg})
    return m_container("h")(e, {"name": n.get("name", "Key"), "w": n.get("w", "hug"), "h": 48,
                                "radius": "medium", "pad": [0, 12, 0, 12], "gap": 4,
                                "main": "center", "cross": "center", "bg": "accentOrange" if lit else "surfaceRaised",
                                **({} if lit else {"border": "borderStrong"}), "c": kids}, parent, pdir)


MACROS = {
    "col": m_container("v"), "row": m_container("h"), "text": m_text, "icon": m_icon, "box": m_box,
    "spacer": m_spacer, "divider": m_divider, "card": m_card, "button": m_button, "chip": m_chip,
    "input": m_input, "avatar": m_avatar, "tile": m_tile, "switch": m_switch, "checkbox": m_checkbox,
    "switchrow": m_switchrow, "tabs": m_tabs, "segmented": m_segmented, "slider": m_slider,
    "progress": m_progress, "section": m_section, "iconbtn": m_iconbtn, "badge": m_badge,
    "appbar": m_appbar, "bottomnav": m_bottomnav, "actionbar": m_actionbar, "fab": m_fab,
    "sheet": m_sheet, "dialog": m_dialog, "raw": m_raw, "tab": m_tab, "segment": m_segment,
    "navitem": m_navitem, "statusbar": m_statusbar,
    "pad": m_pad, "secblock": m_secblock, "partblock": m_secblock, "wave": m_wave, "boundary": m_boundary,
    "playhead": m_playhead, "minimap": m_minimap, "ruler": m_ruler, "beatgrid": m_beatgrid,
    "breadcrumb": m_breadcrumb, "transport": m_transport,
    "overview": m_timeline, "zoomwave": m_timeline, "key": m_key,
}


# ---------------------------------------------------------------- components
# Each reusable widget is a main component (a variant set when it has `axes`) on the Components page.
# Screens place instances of it: duplicate a template instance of the right variant, set its
# properties, override root/layer props, and put spec children into its slots.
# `draw(v)` returns the spec node the main is drawn from (the plain macro, with every optional
# layer present); `inst(n, pdir)` maps a spec node to the instance:
#   v: variant values, p: properties, root: props on the instance, w/h: default sizing,
#   over: {layer: props}, nested: {nested instance layer: properties}, slots: {slot: [nodes]}.
C, TYPE2COMP = {}, {}
ONLINE = False  # True while talking to FigCraft; offline `check` only validates
LIB = {}  # cname -> {variant key: {"tpl": template instance id, "layers": {name: id}}}; empty offline
CREG = os.path.join(HERE, ".components.json")  # cname -> {variant key: main component id}
COMP_PAGE = "Components"


class Unsupported(Exception):
    """The spec node needs something an instance can't override: draw it as plain layers."""


def comp(name, types, draw, inst, axes=None, props=(), slots=(), main_w=360, inline=()):
    """`inline`: spec node types drawn as plain layers in the main even when they have a component of
    their own. A text property can only bind a text layer, so a label inside a nested instance
    (Button) is reachable only when the main draws that button inline with a uniquely named label."""
    C[name] = dict(name=name, types=types, draw=draw, inst=inst, axes=axes or {}, props=props,
                   slots=slots, main_w=main_w, inline=tuple(inline))
    for t in types:
        TYPE2COMP[t] = name


for _pattern, _component in (("song_card", "SongCard"), ("setlist_card", "SetlistCard"),
                              ("member_card", "MemberCard")):
    comp(_component, [], lambda v, pattern=_pattern: {"t": "pattern", "name": pattern,
         "title": "Title", "subtitle": "Subtitle", "meta": "Meta"}, i_pattern,
         props=[("Title", "text", "Title", None), ("Subtitle", "text", "Subtitle", None),
                ("Meta", "text", "Meta", None)])


def glyph(name):
    if name not in ICONS:
        raise ValueError(f"unknown Material icon {name!r}")
    return chr(ICONS[name])


def vkey(c, v):
    return ", ".join(f"{a}={v[a]}" for a in c["axes"]) or "Default"


def combos(c):
    out = [{}]
    for a, vals in c["axes"].items():
        out = [dict(o, **{a: x}) for o in out for x in vals]
    return out


def icon_prop(p, over, name, layer="Icon", show="Show icon"):
    """Icon text property (the glyph) + its visibility; the layer is renamed to the icon's name."""
    if show:
        p[show] = bool(name)
    if name:
        p[layer if layer != "Icon" else "Icon"] = glyph(name)
        over.setdefault(layer, {})["name"] = f"icon/{name}"


def frame_over(n, keys=("bg", "border", "borderW", "radius", "pad", "shadow", "opacity")):
    """Root overrides an instance may take, from container keys in the spec node."""
    o = {}
    if "bg" in n and "bg" in keys:
        o["fill"] = color(n["bg"])
    if "border" in n and "border" in keys:
        o.update(stroke=color(n["border"]), strokeWeight=n.get("borderW", 1), strokeAlign="inside")
    if "radius" in n and "radius" in keys:
        o["cornerRadius"] = radius(n["radius"])
    if "pad" in n and "pad" in keys:
        o["padding"] = n["pad"]
    if n.get("shadow") and "shadow" in keys:
        o["effects"] = [{"type": "dropShadow", "color": "#00000040", "offset": [0, 2], "radius": 8,
                         "visible": True}]
    if "opacity" in n and "opacity" in keys:
        o["opacity"] = n["opacity"]
    return o


def fill_w(pdir):
    return "fill" if pdir == "v" else "hug"


# --- atoms
def i_button(n, pdir):
    kind = n.get("kind", "primary")
    if kind not in SPEC_KIND:
        raise ValueError(f"button kind {kind!r}")
    p, over = {"Label": str(n.get("v", "")), "Show label": bool(n.get("v"))}, {}
    icon_prop(p, over, n.get("icon"))
    size = n.get("size") or ("small" if n.get("small") else "medium")
    state = n.get("state", "default").capitalize()
    return dict(v={"Variant": SPEC_KIND[kind].capitalize(), "Size": size.capitalize(), "State": state},
                p=p, over=over, root={"opacity": .38} if state == "Disabled" else {}, w="hug")


INV_KIND = {"Primary": "primary", "Secondary": "white", "Outline": "secondary", "Text": "text", "Tonal": "tonal",
            "Danger": "danger"}
comp("CustomButton", ["button"],
     lambda v: {"t": "button", "kind": INV_KIND[v["Variant"]], "size": v["Size"].lower(), "v": "Button",
                "icon": "add", "state": v["State"].lower()},
     i_button, axes={"Variant": ["Primary", "Secondary", "Outline", "Text", "Tonal", "Danger"],
                     "Size": ["Medium", "Small", "Large"], "State": ["Default", "Disabled", "Loading"]},
     props=[("Label", "text", "Label", None), ("Show label", "boolean", "Label", True),
            ("Icon", "text", "Icon", None), ("Show icon", "boolean", "Icon", False)])


def i_fab(n, pdir):
    p, over = {"Label": str(n.get("v", "")), "Show label": bool(n.get("v"))}, {}
    icon_prop(p, over, n.get("icon", "add"), show=None)
    return dict(p=p, over=over, w="hug")


comp("FloatingActionButton", ["fab"], lambda v: {"t": "fab", "icon": "add", "v": "Label"}, i_fab,
     props=[("Icon", "text", "Icon", None), ("Label", "text", "Label", None),
            ("Show label", "boolean", "Label", False)])


def i_iconbtn(n, pdir):
    p, over = {}, {}
    icon_prop(p, over, n.get("v"), show=None)
    lo = over.setdefault("Icon", {})
    if "color" in n:
        lo["fill"] = color(n["color"])
    if "size" in n:
        lo.update(fontSize=n["size"], lineHeight=n["size"])
    return dict(p=p, over=over, root=frame_over(n, ("bg", "border", "radius")), w=48, h=48)


comp("IconButton", ["iconbtn"], lambda v: {"t": "iconbtn", "v": "settings"}, i_iconbtn,
     props=[("Icon", "text", "Icon", None)])


def i_chip(n, pdir):
    p, over = {"Label": str(n.get("v", ""))}, {}
    icon_prop(p, over, n.get("icon"))
    state = "Disabled" if n.get("state") == "disabled" else "Selected" if n.get("sel") else "Default"
    return dict(v={"State": state}, p=p, over=over, root={"opacity": .38} if state == "Disabled" else {}, w="hug")


comp("AppFilterChip", ["chip"], lambda v: {"t": "chip", "v": "Chip", "icon": "add", "sel": v["State"] == "Selected",
                                   "state": "disabled" if v["State"] == "Disabled" else "default"},
     i_chip, axes={"State": ["Default", "Selected", "Disabled"]},
     props=[("Label", "text", "Label", None), ("Icon", "text", "Icon", None),
            ("Show icon", "boolean", "Icon", False)])


def i_badge(n, pdir):
    p, over = {"Label": str(n.get("v", ""))}, {}
    icon_prop(p, over, n.get("icon"))
    if "color" in n:
        over.setdefault("Label", {})["fill"] = color(n["color"])
        over.setdefault("Icon", {})["fill"] = color(n["color"])
    return dict(p=p, over=over, root=frame_over(n, ("bg",)), w="hug")


comp("AppBadge", ["badge"], lambda v: {"t": "badge", "v": "Badge", "icon": "star"}, i_badge,
     props=[("Label", "text", "Label", None), ("Icon", "text", "Icon", None),
            ("Show icon", "boolean", "Icon", False)])


comp("ChordChartView", [], lambda v: {"t": "col", "name": "ChordChartView", "gap": 10, "cross": "min", "c": [
    {"t": "row", "gap": 8, "cross": "min", "c": [
        {"t": "col", "gap": 2, "cross": "min", "c": [
            {"t": "text", "v": "G", "style": "bodyLarge", "color": "accentOrange", "w": "hug"},
            {"t": "text", "v": "Amazing", "style": "bodyLarge", "color": "textPrimary", "name": "Lyric", "w": "hug"}]},
        {"t": "col", "gap": 2, "cross": "min", "c": [
            {"t": "text", "v": "D", "style": "bodyLarge", "color": "accentOrange", "w": "hug"},
            {"t": "text", "v": "grace", "style": "bodyLarge", "color": "textPrimary", "w": "hug"}]}]}]},
     lambda n, pdir: {"p": {"Lyric": n.get("chart", "Amazing")}},
     props=[("Lyric", "text", "Lyric", "Amazing")])

comp("PerformanceSheetView", [], lambda v: {"t": "col", "name": "PerformanceSheetView", "gap": 12, "w": "fill", "c": [
    {"t": "col", "gap": 8, "w": "fill", "c": [
        {"t": "text", "v": "Verse", "style": "titleMedium", "color": "accentOrange", "name": "Section"},
        {"t": "row", "gap": 8, "cross": "min", "c": [
            {"t": "col", "gap": 2, "cross": "min", "c": [
                {"t": "text", "v": "G", "style": "headlineSmall", "color": "accentOrange", "w": "hug"},
                {"t": "text", "v": "Amazing", "style": "headlineSmall", "name": "Lyric", "w": "hug"}]},
            {"t": "col", "gap": 2, "cross": "min", "c": [
                {"t": "text", "v": "D", "style": "headlineSmall", "color": "accentOrange", "w": "hug"},
                {"t": "text", "v": "grace", "style": "headlineSmall", "w": "hug"}]}]}]},
    {"t": "col", "gap": 4, "bg": "surfaceRaised", "radius": 6, "pad": 8, "w": "fill", "c": [
        {"t": "row", "gap": 8, "cross": "center", "c": [
            {"t": "icon", "v": "music_note", "size": 20, "color": "textSecondary"},
            {"t": "text", "v": "Semitones", "style": "labelLarge"},
            {"t": "spacer"}, {"t": "icon", "v": "remove", "size": 20},
            {"t": "text", "v": "Original", "style": "labelLarge"}, {"t": "icon", "v": "add", "size": 20}]},
        {"t": "row", "gap": 8, "cross": "center", "c": [
            {"t": "icon", "v": "play_arrow", "size": 20},
            {"t": "icon", "v": "remove", "size": 20},
            {"t": "text", "v": "35 px/s", "style": "labelLarge"},
            {"t": "icon", "v": "add", "size": 20}, {"t": "spacer"},
            {"t": "badge", "v": "Manual"}]}]}]},
     lambda n, pdir: {"p": {"Section": n.get("section", "Verse"),
                            "Lyric": n.get("lyric", "Amazing")}},
     props=[("Section", "text", "Section", "Verse"), ("Lyric", "text", "Lyric", "Amazing")])


# Reused widget components. Each preview draws the actual visual structure of
# its Flutter widget; the named text layers are the Code Connect properties.
def _component_instance(values):
    return lambda n, pdir: {"p": dict(values(n))}


comp("LoadingIndicator", [], lambda v: {"t": "col", "name": "LoadingIndicator", "main": "center",
     "cross": "center", "gap": 16, "c": [
         {"t": "icon", "v": "autorenew", "size": 40, "color": "accentOrange", "name": "Progress"},
         {"t": "text", "v": "Loading", "style": "bodyMedium", "color": "textPrimary", "name": "Message"}]},
     _component_instance(lambda n: {"Message": n.get("message", "Loading")}),
     props=[("Message", "text", "Message", "Loading")])
comp("ErrorBanner", [], lambda v: {"t": "col", "name": "ErrorBanner", "bg": "error10", "border": "error30",
     "radius": 8, "pad": 16, "gap": 8, "c": [
         {"t": "row", "cross": "center", "gap": 8, "c": [
             {"t": "icon", "v": "error_outline", "size": 24, "color": "error"},
             {"t": "text", "v": "Error title", "style": "titleMedium", "color": "error", "name": "Title"}]},
         {"t": "text", "v": "Error message", "style": "bodyMedium", "color": "textPrimary", "name": "Message"},
         {"t": "button", "kind": "danger", "v": "Retry", "icon": "refresh"}]},
     _component_instance(lambda n: {"Message": n.get("message", "Error message"),
                                    "Title": n.get("title", "Error title")}),
     axes={"Style": ["Banner", "Card", "Inline"]},
     props=[("Message", "text", "Message", "Error message"), ("Title", "text", "Title", "Error title")])
comp("QuickActionButton", [], lambda v: {"t": "row", "name": "QuickActionButton", "bg": "surfaceRaised",
     "border": "borderDefault", "radius": 6, "pad": [12, 4, 12, 4], "gap": 8, "cross": "center", "c": [
         {"t": "icon", "v": "add", "size": 24, "color": "accentOrange", "name": "Icon"},
         {"t": "text", "v": "Quick action", "style": "labelLarge", "color": "textPrimary", "name": "Label",
          "maxLines": 2}]},
     _component_instance(lambda n: {"Label": n.get("label", "Quick action")}),
     props=[("Label", "text", "Label", "Quick action")])
comp("EmptyState", [], lambda v: {"t": "col", "name": "EmptyState", "main": "center", "cross": "center",
     "c": [
         {"t": "icon", "v": "music_note", "size": 80, "color": "textTertiary", "name": "Icon"},
         {"t": "spacer", "size": 16},
         {"t": "text", "v": "No items yet", "style": "headlineSmall", "color": "textPrimary", "name": "Message"},
         {"t": "spacer", "size": 8},
         {"t": "text", "v": "Add something to get started", "style": "bodyMedium", "color": "textTertiary",
          "name": "Hint"},
         {"t": "spacer", "size": 24},
         {"t": "button", "kind": "secondary", "v": "Add item", "icon": "add", "rootName": "Action",
          "labelName": "Action label"},
         {"t": "spacer", "size": 8},
         {"t": "button", "kind": "secondary", "v": "Other action", "icon": "group_add",
          "rootName": "SecondaryAction", "labelName": "SecondaryAction label"}]},
     _component_instance(lambda n: {"Message": n.get("message", "No items yet"),
                                    "Hint": n.get("hint", "Add something to get started"),
                                    "Action": n.get("actionLabel", "Add item"),
                                    "SecondaryAction": n.get("secondaryActionLabel", "Other action")}),
     props=[("Message", "text", "Message", "No items yet"), ("Hint", "text", "Hint", "Add something to get started"),
            ("Action", "text", "Action label", "Add item"),
            ("SecondaryAction", "text", "SecondaryAction label", "Other action")],
     inline=("button",))

comp("TimeSignatureBlock", [], lambda v: {"t": "col", "name": "TimeSignatureBlock", "bg": "blackSurface",
     "border": "borderSubtle", "radius": 16, "pad": 16, "gap": 10, "c": [
         {"t": "text", "v": "Beats (badge = count)", "style": "bodyMedium", "color": "textSecondary"},
         {"t": "row", "cross": "center", "gap": 8, "c": [
             {"t": "button", "kind": "secondary", "v": "−"},
             {"t": "icon", "v": "circle", "size": 16, "color": "beatModeNormal"},
             {"t": "icon", "v": "star", "size": 16, "color": "beatModeAccent"},
             {"t": "icon", "v": "block", "size": 16, "color": "textDisabled"},
             {"t": "button", "kind": "secondary", "v": "+", "badge": "4"}]},
         {"t": "text", "v": "Subdivisions (badge = count)", "style": "bodyMedium", "color": "textSecondary"},
         {"t": "row", "cross": "center", "gap": 8, "c": [
             {"t": "button", "kind": "secondary", "v": "−"},
             {"t": "icon", "v": "circle", "size": 16, "color": "beatModeNormal"},
             {"t": "icon", "v": "circle", "size": 16, "color": "beatModeNormal"},
             {"t": "button", "kind": "secondary", "v": "+", "badge": "2"}]},
         {"t": "text", "v": "Dot: normal · Star: accent · ⊘: silent. Tap to change.",
          "style": "bodySmall", "color": "textSecondary"}]},
     _component_instance(lambda n: {}))

def _tempo_step(label, x, y, name):
    return [{"t": "box", "circle": True, "bg": "surfaceRaised", "border": "borderDefault", "borderW": 1.5,
             "w": 52, "h": 52, "abs": [x, y], "name": name + " circle"},
            {"t": "col", "w": 52, "h": 52, "abs": [x, y], "main": "center", "cross": "center", "c": [
                {"t": "text", "v": label, "style": "labelLarge", "color": "textSecondary", "name": name,
                 "w": "hug"}]}]


comp("TempoControlCluster", [], lambda v: {"t": "col", "name": "TempoControlCluster", "w": 300, "h": 300, "c": [
         {"t": "box", "circle": True, "bg": "blackSurface", "w": 300, "h": 300, "abs": [0, 0], "name": "Dial"},
         {"t": "col", "w": 300, "h": 300, "abs": [0, 0], "main": "center", "cross": "center", "c": [
             {"t": "text", "v": "120", "style": "displayMedium", "color": "accentOrange", "name": "Tempo",
              "w": "hug"},
             {"t": "text", "v": "BPM", "style": "labelMedium", "color": "textSecondary", "w": "hug"}]},
         *_tempo_step("−5", 0, 0, "Decrease 5"), *_tempo_step("+5", 248, 0, "Increase 5"),
         *_tempo_step("−1", 0, 248, "Decrease 1"), *_tempo_step("+1", 248, 248, "Increase 1")]},
     _component_instance(lambda n: {}), main_w=300)

comp("StatCard", [], lambda v: {"t": "col", "name": "StatCard", "bg": "surfaceRaised", "border": "borderSubtle",
     "radius": 7, "pad": [16, 8, 16, 8], "main": "center", "cross": "center", "gap": 4, "c": [
         {"t": "icon", "v": "speed", "size": 24, "color": "accentOrange", "layer": "Icon"},
         {"t": "text", "v": "24", "style": "titleLarge", "color": "accentOrange", "name": "Value", "maxLines": 1},
         {"t": "text", "v": "Songs", "style": "bodySmall", "color": "textTertiary", "name": "Label", "maxLines": 1}]},
     _component_instance(lambda n: {"Icon": glyph(n.get("icon", "speed")), "Value": n.get("value", "24"),
                                    "Label": n.get("label", "Songs")}),
     props=[("Icon", "text", "Icon", "speed"), ("Value", "text", "Value", "24"),
            ("Label", "text", "Label", "Songs")])

comp("SongLibraryBlock", [], lambda v: {"t": "col", "name": "SongLibraryBlock", "gap": 8, "c": [
     {"t": "row", "name": "Library action", "bg": "surface", "border": "borderSubtle", "radius": 20,
      "pad": [20, 12, 20, 12], "gap": 12, "cross": "center", "c": [
          {"t": "icon", "v": "library_music_outlined", "size": 24, "color": "textSecondary"},
          {"t": "text", "v": "Songs & Setlists", "style": "bodyLarge", "color": "textHighEmphasis",
           "name": "Library label"}]},
     {"t": "row", "name": "Loaded song card", "bg": "surface", "border": "borderSubtle", "radius": 12,
      "pad": [16, 12, 16, 12], "gap": 12, "cross": "center", "c": [
          {"t": "icon", "v": "music_note", "size": 24, "color": "accentOrange"},
          {"t": "col", "gap": 2, "c": [
              {"t": "text", "v": "First Song", "style": "bodyMedium", "color": "textHighEmphasis",
               "name": "Song title"},
              {"t": "text", "v": "Test Band", "style": "bodySmall", "color": "textTertiary", "name": "Song source"}]},
          {"t": "icon", "v": "close", "size": 20, "color": "textSecondary"}]}]},
     _component_instance(lambda n: {}))

comp("SetlistSongRow", [], lambda v: {"t": "col", "name": "SetlistSongRow", "bg": "surface", "c": [
     {"t": "row", "name": "Row", "pad": [0, 8, 16, 8], "gap": 12, "cross": "center", "c": [
         {"t": "box", "w": 3, "h": 40, "bg": "selectionInk", "name": "Current bar"},
         {"t": "col", "w": 44, "cross": "center", "c": [
             {"t": "text", "v": "01", "style": "labelLarge", "color": "textTertiary", "name": "Index",
              "w": "hug"}]},
         {"t": "col", "gap": 2, "w": "fill", "c": [
             {"t": "text", "v": "First Song", "style": "bodyLarge", "color": "textPrimary", "name": "Title"},
             {"t": "text", "v": "Test Band", "style": "bodyMedium", "color": "textSecondary", "name": "Artist"},
             {"t": "text", "v": "Performers", "style": "bodySmall", "color": "textTertiary", "name": "Performers"}]},
         {"t": "text", "v": "B♭m · 120 BPM", "style": "labelSmall", "color": "textSecondary", "name": "Details"}]},
     {"t": "box", "w": "fill", "h": 1, "bg": "borderSubtle", "name": "Bottom border"}]},
     _component_instance(lambda n: {"Index": str(n.get("index", "01")), "Title": n.get("title", "First Song"),
                                    "Artist": n.get("artist", "Test Band"),
                                    "Performers": n.get("performers", "Performers"),
                                    "Details": n.get("details", "B♭m · 120 BPM"),
                                    "isCurrent": n.get("isCurrent", False)}),
     props=[("Index", "text", "Index", "01"), ("Title", "text", "Title", "First Song"),
            ("Artist", "text", "Artist", "Test Band"), ("Performers", "text", "Performers", "Performers"),
            ("Details", "text", "Details", "B♭m · 120 BPM"), ("isCurrent", "boolean", "Current bar", False)])

comp("SetlistBreakRow", [], lambda v: {"t": "row", "name": "SetlistBreakRow", "bg": "surfaceRaised",
     "border": "borderDefault", "radius": 8, "pad": [12, 8, 12, 8], "gap": 12, "cross": "center", "c": [
         {"t": "icon", "v": "pause_circle_outline", "size": 18, "color": "textTertiary"},
         {"t": "text", "v": "Break", "style": "labelLarge", "color": "textSecondary", "name": "Label", "w": "fill"}]},
     _component_instance(lambda n: {"Label": n.get("label", "Break")}),
     props=[("Label", "text", "Label", "Break")])

comp("SectionCard", [], lambda v: {"t": "col", "name": "SectionCard", "bg": "surfaceRaised",
     "border": "borderSubtle", "radius": 7, "pad": 16, "gap": 8, "c": [
         {"t": "text", "v": "Verse · " + ("Next bar" if v["Queued"] == "Next bar" else "Playing"),
          "style": "titleMedium", "color": "accentOrange", "name": "Section", "maxLines": 1},
         {"t": "text", "v": "C     G     Am     F", "style": "bodyMedium", "color": "textPrimary", "name": "Chord chart"}]},
     lambda n, pdir: {"v": {"Queued": "Next bar" if n.get("queued") else "Playing"}, "p": {}},
     axes={"Queued": ["Playing", "Next bar"]})

comp("PrimaryActionBar", [], lambda v: {"t": "col", "name": "PrimaryActionBar", "bg": "surface",
     "pad": 16, "gap": 12, "c": [
         {"t": "row", "gap": 12, "c": [
             {"t": "button", "kind": "outline", "v": "Cancel", "rootName": "Secondary",
              "labelName": "Secondary label", "w": "fill"},
             {"t": "button", "kind": "primary", "v": "Save", "icon": "save", "rootName": "Primary",
              "labelName": "Primary label", "w": "fill"}]}]},
     _component_instance(lambda n: {"Label": n.get("label", "Save"), "SecondaryLabel": n.get("secondaryLabel", "Cancel")}),
     props=[("Label", "text", "Primary label", "Save"), ("SecondaryLabel", "text", "Secondary label", "Cancel")],
     inline=("button",))

comp("ToolButton", [], lambda v: {"t": "row", "name": "ToolButton", "bg": "surfaceRaised",
     "border": "borderDefault", "radius": 6, "pad": [12, 4, 12, 4], "gap": 8, "cross": "center", "c": [
         {"t": "icon", "v": "tune", "size": 24, "color": "textSecondary", "layer": "Icon"},
         {"t": "text", "v": "Tool", "style": "labelLarge", "color": "textPrimary", "name": "Label", "maxLines": 2},
         {"t": "row", "name": "Soon badge", "bg": "borderStrong", "radius": 8, "pad": [8, 2, 8, 2], "c": [
             {"t": "text", "v": "Soon", "style": "labelSmall", "color": "textPrimary", "name": "Soon"}]}]},
     _component_instance(lambda n: {"Label": n.get("label", "Tool"), "Icon": glyph(n.get("icon", "tune"))}),
     props=[("Label", "text", "Label", "Tool"), ("Icon", "text", "Icon", "tune")])
comp("SingleFab", [], lambda v: {"t": "row", "name": "SingleFab", "bg": "white", "border": "charcoal",
     "borderW": 1.2, "radius": 6,
     "pad": [16, 16, 16, 16], "main": "center", "cross": "center", "c": [
         {"t": "icon", "v": "add", "size": 24, "color": "charcoal", "layer": "Icon"}]},
     _component_instance(lambda n: {"Icon": glyph(n.get("icon", "add"))}),
     props=[("Icon", "text", "Icon", "add")])
comp("UnifiedFilterSortWidget", [], lambda v: {"t": "row", "name": "UnifiedFilterSortWidget", "gap": 8,
     "cross": "center", "c": [
         {"t": "row", "name": "Filter", "bg": "white", "border": "borderDefault", "borderW": 2, "radius": 10,
          "pad": [14, 14, 14, 14], "gap": 0, "cross": "center", "w": "fill", "c": [
              {"t": "text", "v": "Search...", "style": "bodyLarge", "color": "#62625A", "w": "hug",
               "name": "Hint"},
              {"t": "text", "v": "", "style": "bodyLarge", "color": "#1E1E1C", "w": "hug",
               "name": "Filter value"}]},
         {"t": "row", "name": "Sort", "bg": "surface", "border": "borderDefault", "radius": 8,
          "pad": [8, 0, 8, 0], "gap": 8, "cross": "center", "c": [
              {"t": "text", "v": "Manual order", "style": "bodyMedium", "color": "textPrimary", "name": "Sort option"},
              {"t": "icon", "v": "sort", "size": 20, "color": "textSecondary"}]}]},
     _component_instance(lambda n: {"Filter": n.get("filterText", ""), "Hint": n.get("hintText", "Search..."),
                                    "Sort": "Manual order"}),
     props=[("Filter", "text", "Filter value", ""), ("Hint", "text", "Hint", "Search..."),
            ("Sort", "text", "Sort option", "Manual order")])
comp("ConfirmationDialog", [], lambda v: {"t": "dialog", "name": "ConfirmationDialog", "bg": "surface",
     "radius": 16, "pad": 16, "gap": 12, "cross": "center", "c": [
         {"t": "icon", "v": "warning_amber", "size": 48, "color": "error", "layer": "Icon"},
         {"t": "text", "v": "Confirm", "style": "titleMedium", "color": "textPrimary", "name": "Title"},
         {"t": "text", "v": "Are you sure?", "style": "bodyMedium", "color": "textSecondary", "name": "Message"},
         {"t": "row", "cross": "center", "gap": 8, "c": [
             {"t": "button", "kind": "text", "v": "Cancel", "rootName": "Cancel button", "labelName": "Cancel"},
             {"t": "button", "kind": "danger", "v": "Confirm", "rootName": "Confirm button",
              "labelName": "Confirm"}]}]},
     _component_instance(lambda n: {"Title": n.get("title", "Confirm"), "Message": n.get("message", "Are you sure?"),
                                    "confirmLabel": n.get("confirmLabel", "Confirm"),
                                    "cancelLabel": n.get("cancelLabel", "Cancel")}),
     props=[("Title", "text", "Title", "Confirm"), ("Message", "text", "Message", "Are you sure?"),
            ("confirmLabel", "text", "Confirm", "Confirm"), ("cancelLabel", "text", "Cancel", "Cancel"),
            ("Icon", "text", "Icon", "warning_amber")], inline=("button",))


def i_avatar(n, pdir):
    s = n.get("size", 40)
    p, over = {}, {}
    if n.get("icon"):
        icon_prop(p, over, n["icon"], show=None)
        over["Icon"].update(fontSize=s * 0.55, lineHeight=s * 0.55)
    else:
        p["Initials"] = str(n.get("v", "?"))
    lay = "Icon" if n.get("icon") else "Initials"
    if "color" in n:
        over.setdefault(lay, {})["fill"] = color(n["color"])
    root = frame_over(n, ("bg",))
    root["cornerRadius"] = s / 2
    return dict(v={"Type": "Icon" if n.get("icon") else "Initials"}, p=p, over=over, root=root, w=s, h=s)


comp("UserAvatar", ["avatar"], lambda v: {"t": "avatar", "v": "AR"} if v["Type"] == "Initials"
     else {"t": "avatar", "icon": "person"}, i_avatar, axes={"Type": ["Initials", "Icon"]},
     props=[("Initials", "text", "Initials", None), ("Icon", "text", "Icon", None)])

comp("Switch", ["switch"], lambda v: {"t": "switch", "on": v["State"] == "On"},
     lambda n, pdir: dict(v={"State": "On" if n.get("on", True) else "Off"}, w=52, h=32),
     axes={"State": ["On", "Off"]})
comp("Checkbox", ["checkbox"], lambda v: {"t": "checkbox", "on": v["State"] == "On"},
     lambda n, pdir: dict(v={"State": "On" if n.get("on") else "Off"}, w=20, h=20),
     axes={"State": ["On", "Off"]})


def i_input(n, pdir):
    p, over = {"Label": str(n.get("label", "")), "Show label": bool(n.get("label")),
               "Value": str(n.get("v") or n.get("hint", ""))}, {}
    icon_prop(p, over, n.get("icon"))
    icon_prop(p, over, n.get("trail"), layer="Trail", show="Show trail")
    if n.get("trail"):
        p["Trail"] = p.pop("Trail")
    state = n.get("state") or ("filled" if n.get("v") else "hint")
    return dict(v={"State": state.capitalize(), "Lines": "Multi" if n.get("lines") else "Single"},
                p=p, over=over, root={"opacity": .38} if state == "disabled" else {}, w=fill_w(pdir))


comp("CustomTextField", ["input"],
     lambda v: {"t": "input", "label": "Label", "icon": "search", "trail": "close", "hint": "Hint",
                "v": "Value" if v["State"] in ("Filled", "Focus", "Error") else None,
                "state": v["State"].lower(), "helper": "Please check this field",
                "lines": 3 if v["Lines"] == "Multi" else None},
     i_input, axes={"State": ["Hint", "Filled", "Focus", "Error", "Disabled"], "Lines": ["Single", "Multi"]},
     props=[("Label", "text", "Label", None), ("Show label", "boolean", "Label", True),
            ("Value", "text", "Value", None), ("Icon", "text", "Icon", None),
            ("Show icon", "boolean", "Icon", False), ("Trail", "text", "Trail", None),
            ("Show trail", "boolean", "Trail", False)])

STEPS = [str(i) for i in range(0, 101, 10)]


def step(v):
    return str(int(round(max(0.0, min(1.0, v)) * 10)) * 10)


comp("Slider", ["slider"], lambda v: {"t": "slider", "value": int(v["Value"]) / 100, "w": 300},
     lambda n, pdir: dict(v={"Value": step(n.get("value", 0.5))}, w=n.get("w", "fill")),
     axes={"Value": STEPS}, main_w=300)


def i_progress(n, pdir):
    over = {"Fill": {"fill": color(n["color"])}} if "color" in n else {}
    return dict(v={"Value": step(n.get("value", 0.5))}, over=over, w="fill")


comp("LinearProgressIndicator", ["progress"], lambda v: {"t": "progress", "value": int(v["Value"]) / 100}, i_progress,
     axes={"Value": STEPS})

# --- navigation items
comp("Tab", ["tab"], lambda v: {"t": "tab", "v": "Tab", "sel": v["State"] == "Selected", "w": 120},
     lambda n, pdir: dict(v={"State": "Selected" if n.get("sel") else "Default"}, p={"Label": str(n.get("v", ""))},
                          w=n.get("w", "fill")),
     axes={"State": ["Selected", "Default"]}, props=[("Label", "text", "Label", None)])
comp("ButtonSegment", ["segment"], lambda v: {"t": "segment", "v": "Segment", "sel": v["State"] == "Selected", "w": 120},
     lambda n, pdir: dict(v={"State": "Selected" if n.get("sel") else "Default"}, p={"Label": str(n.get("v", ""))},
                          w=n.get("w", "fill")),
     axes={"State": ["Selected", "Default"]}, props=[("Label", "text", "Label", None)])


def i_navitem(n, pdir):
    p, over = {"Label": str(n.get("v", ""))}, {}
    icon_prop(p, over, n.get("icon", "home"), show=None)
    return dict(v={"State": "Selected" if n.get("sel") else "Default"}, p=p, over=over, w="fill")


comp("NavTab", ["navitem"], lambda v: {"t": "navitem", "v": "Home", "icon": nav_icon("home", v["State"] == "Selected"),
                                        "sel": v["State"] == "Selected", "w": 76},
     i_navitem, axes={"State": ["Selected", "Default"]},
     props=[("Label", "text", "Label", None), ("Icon", "text", "Icon", None)])
NAV_SEL = [t for t, _ in NAV_TABS] + ["None"]
comp("StatusBar", ["statusbar"], lambda v: {"t": "statusbar"},
     lambda n, pdir: dict(root=frame_over(n, ("bg",)), w="fill"), main_w=W)


# --- composites with slots
def i_section(n, pdir):
    p = {"Title": str(n.get("v", "")), "Action": str(n.get("action", "")), "Show action": bool(n.get("action"))}
    v = {"Style": "Label" if n.get("kind") == "label" else "Title"}
    over = {}
    if "style" in n:
        over.setdefault("Title", {})["textStyle"] = f"Type/{n['style']}"
    if "color" in n:
        over.setdefault("Title", {})["fill"] = color(n["color"])
    return dict(v=v, p=p, over=over, root=frame_over(n, ("pad",)), w=fill_w(pdir))


comp("SectionHeader", ["section"],
     lambda v: {"t": "section", "v": "Section", "action": "See all", "kind": v["Style"].lower()}, i_section,
     axes={"Style": ["Title", "Label"]}, props=[("Title", "text", "Title", None), ("Action", "text", "Action", None),
            ("Show action", "boolean", "Action", False)])


def i_tile(n, pdir, switch=None):
    trail = n.get("trail")
    trail = trail if isinstance(trail, list) else ([trail] if trail else [])
    p = {"Title": str(n.get("title") or ""), "Subtitle": str(n.get("sub") or ""), "Show subtitle": bool(n.get("sub")),
         "Show leading": bool(n.get("lead"))}
    slots = {"Leading": [lead_node(n["lead"])] if n.get("lead") else []}
    if switch is None:
        p["Show trailing"] = bool(trail)
        slots["Trailing"] = [trail_node(t) for t in trail]
    over = {"Title": {"textStyle": f"Type/{n['titleStyle']}"}} if n.get("titleStyle") else {}
    out = dict(p=p, over=over, slots=slots, root=frame_over(n, ("bg", "border", "radius", "pad")), w=fill_w(pdir))
    if switch is None:
        out["v"] = {"State": "Selected" if n.get("selected") else "Default"}
        if n.get("selected"):
            out["root"]["fill"] = color("accentOrange10")
    if switch is not None:
        out["v"] = {"State": "On" if switch else "Off"}
    return out


TILE_PROPS = [("Title", "text", "Title", None), ("Subtitle", "text", "Subtitle", None),
              ("Show subtitle", "boolean", "Subtitle", True), ("Show leading", "boolean", "Leading", False)]
comp("ListTile", ["tile"], lambda v: {"t": "tile", "title": "Title", "sub": "Subtitle", "_slots": True,
                                        "selected": v["State"] == "Selected"}, i_tile,
     axes={"State": ["Default", "Selected"]},
     props=TILE_PROPS + [("Show trailing", "boolean", "Trailing", False)],
     slots=[("Leading", "Leading", "h"), ("Trailing", "Trailing", "h")])
comp("SwitchListTile", ["switchrow"],
     lambda v: {"t": "switchrow", "title": "Title", "sub": "Subtitle", "on": v["State"] == "On", "_slots": True},
     lambda n, pdir: i_tile(n, pdir, switch=n.get("on", True)) | {
         "root": frame_over(n, ("pad",))},
     axes={"State": ["On", "Off"]}, props=TILE_PROPS, slots=[("Leading", "Leading", "h")])


def i_appbar(n, pdir):
    back = bool(n.get("back", True) or n.get("leading"))
    p = {"Title": str(n.get("v", "")), "Subtitle": str(n.get("sub", "")), "Show subtitle": bool(n.get("sub"))}
    over = {"Title": {"textStyle": f"Type/{n['style']}"}} if n.get("style") else {}
    nested = {"Leading": {"Icon": glyph(n.get("leading", "arrow_back"))}} if back else {}
    acts = [a if isinstance(a, dict) else {"t": "iconbtn", "v": a} for a in n.get("actions", [])]
    return dict(v={"Leading": "Back" if back else "None"}, p=p, over=over, nested=nested,
                slots={"Actions": acts}, root=frame_over(n, ("bg",)), w="fill")


comp("AppBar", ["appbar"], lambda v: {"t": "appbar", "v": "Title", "back": v["Leading"] == "Back", "_slots": True},
     i_appbar, axes={"Leading": ["Back", "None"]}, main_w=W,
     props=[("Title", "text", "Title", None), ("Subtitle", "text", "Subtitle", None),
            ("Show subtitle", "boolean", "Subtitle", False)],
     slots=[("Actions", "Actions", "h")])


def i_actionbar(n, pdir):
    nested = {}
    if n.get("primary"):
        bp, over = {"Label": str(n["primary"]), "Show label": True}, {}
        icon_prop(bp, over, n.get("icon"))
        nested["Primary"] = bp
    p = {"Title": str(n.get("title", "")), "Show title": bool(n.get("title")) and not n.get("primary"),
         "Show primary": bool(n.get("primary")), "Show menu": bool(n.get("menu", True))}
    return dict(p=p, nested=nested, w="fill")


def i_bottombar(n, pdir):
    if n["t"] == "actionbar":
        return {**i_actionbar(n, pdir), "v": {"Tab": "Actions"}}
    return dict(v={"Tab": n.get("sel") if n.get("sel") in NAV_SEL else "None"}, w="fill")


comp("AppBottomBar", ["actionbar", "bottomnav"],
     lambda v: ({"t": "actionbar", "title": "Title", "primary": "Save", "_slots": True}
                if v["Tab"] == "Actions" else {"t": "bottomnav", "sel": v["Tab"]}),
     i_bottombar, axes={"Tab": NAV_SEL + ["Actions"]}, main_w=W,
     props=[("Title", "text", "Title", None), ("Show title", "boolean", "Title", True),
            ("Show primary", "boolean", "Primary", False), ("Show menu", "boolean", "Menu", True)])

def i_card(n, pdir):
    if n.get("wrap"):
        raise Unsupported("wrapping card content")
    over = {"Content": {k2: (align(n[k]) if k != "gap" else n[k])
                        for k, k2 in (("gap", "gap"), ("main", "mainAlign"), ("cross", "crossAlign")) if k in n}}
    return dict(v={"Direction": "Horizontal" if n.get("dir") == "h" else "Vertical"},
                root=frame_over(n), over=over, slots={"Content": n.get("c", [])}, w=fill_w(pdir))


comp("AppCard", ["card"], lambda v: {"t": "card", "dir": "h" if v["Direction"] == "Horizontal" else "v"}, i_card,
     axes={"Direction": ["Vertical", "Horizontal"]}, slots=[("Content", "Content", "dir")])


def i_sheet(n, pdir):
    over = {"Content": {"gap": n["gap"]}} if "gap" in n else {}
    return dict(v={"Docked": "Bottom" if n.get("bottom", True) else "Floating"}, root=frame_over(n, ("pad",)),
                over=over, slots={"Content": n.get("c", [])}, w=fill_w(pdir))


comp("ModalBottomSheet", ["sheet"], lambda v: {"t": "sheet", "bottom": v["Docked"] == "Bottom"}, i_sheet,
     axes={"Docked": ["Bottom", "Floating"]}, slots=[("Content", "Content", "v")], main_w=W)


def i_dialog(n, pdir):
    p, over = {"Title": str(n.get("title", "")), "Show title": bool(n.get("title")),
               "Show content": bool(n.get("c")), "Show actions": bool(n.get("actions"))}, {}
    icon_prop(p, over, n.get("icon"))
    if n.get("iconColor"):
        over.setdefault("Icon", {})["fill"] = color(n["iconColor"])
    return dict(p=p, over=over, slots={"Content": n.get("c", []), "Actions": n.get("actions", [])},
                w=n.get("w", "fill"))


comp("AlertDialog", ["dialog"], lambda v: {"t": "dialog", "_slots": True}, i_dialog, main_w=340,
     props=[("Title", "text", "Title", None), ("Show title", "boolean", "Title", True),
            ("Icon", "text", "Icon", None), ("Show icon", "boolean", "Icon", False),
            ("Show content", "boolean", "Content", True), ("Show actions", "boolean", "Actions", True)],
     slots=[("Content", "Content", "v"), ("Actions", "Actions", "h")])


# --- song map
PAD_STATES = ["Idle", "Selected", "Playing", "Queued", "Disabled"]
BLOCK_STATES = ["Confirmed", "Candidate", "Selected", "Playing"]
BOUNDARY_STATES = ["Confirmed", "Candidate", "Selected"]


def i_pad(n, pdir):
    state = n.get("state", "idle")
    progress = pad_progress(n)
    over = {"Loop progress": progress} if state == "playing" else {
        "Stripe": {"fill": color(n.get("color", "section1"))}}
    return dict(v={"State": state.title()}, p={"Label": str(n.get("label", "")),
                "Subtitle": str(n.get("sub", ""))}, over=over, w=180, h=80)


def i_secblock(n, pdir):
    state = n.get("state", "confirmed")
    default_w = 80 if n["t"] == "partblock" else 112
    tint_w = max(1, n.get("w", default_w) - 6)
    over = {"Tint": {"fill": color(n.get("color", "section1")), "width": tint_w}}
    if state == "playing":
        over["Playing tint"] = {"width": tint_w}
    p = {"Label": str(block_label(n))}
    if n["t"] == "partblock":
        p["Letter"] = str(n.get("letter", ""))
    return dict(v={"State": state.title()}, p=p,
                over=over, w=default_w, h=48)


def i_boundary(n, pdir):
    return dict(v={"State": n.get("state", "confirmed").title()}, w=16, h=72)


def i_playhead(n, pdir):
    return dict(w=16, h=72)


def i_minimap(n, pdir):
    total, viewport = minimap_viewport(n)
    return dict(over={"Viewport": viewport}, slots={"Sections": minimap_sections(n)}, w=max(1, total), h=16)


def i_timeline(n, pdir):
    if n.get("_timeline_content"):
        raise Unsupported("draw timeline geometry inside the slot")
    return dict(w="fill", slots={"Timeline": timeline_content(n)})


def i_key(n, pdir):
    p, over = {"Label": str(n["v"])}, {}
    icon_prop(p, over, n.get("icon"))
    return dict(v={"State": "Lit" if n.get("lit") else "Idle"}, p=p, over=over, w="hug", h=48)


def song_map_component(name, t, inst, sample=None, states=None, labels=(), slot=None, main_w=380):
    axes = {"Mode": list(MODES.values())}
    if states:
        axes["State"] = states

    def draw(v):
        node = {"t": t, **(sample or {})}
        if states:
            node["state"] = v["State"].lower()
        if slot:
            node["_slots"] = True
        return node

    comp(name, [t], draw, inst, axes=axes, main_w=main_w,
         props=[(label, "text", label, None) for label in labels],
         slots=[(slot, slot, "h")] if slot else [])


song_map_component("SongMapPads", "pad", i_pad, {"label": "Chorus 1", "letter": "C", "color": "section3",
                                        "sub": "12 bars", "progress": .4},
                   PAD_STATES, ("Label", "Subtitle"), main_w=180)
song_map_component("SectionBlock", "secblock", i_secblock, {"letter": "C"},
                   BLOCK_STATES, ("Label",), main_w=112)
song_map_component("PartBlock", "partblock", i_secblock, {"letter": "b", "bars": 4},
                   BLOCK_STATES, ("Letter", "Label"), main_w=80)
song_map_component("Boundary", "boundary", i_boundary, states=BOUNDARY_STATES, main_w=16)
song_map_component("Playhead", "playhead", i_playhead, main_w=16)
song_map_component("Minimap", "minimap", i_minimap,
                   {"sections": [{"color": "section1", "w": 88}, {"color": "section5", "w": 112},
                                 {"color": "section7", "w": 80}], "viewport": [72, 144]}, slot="Sections")
song_map_component("Ruler", "ruler", lambda n, pdir: dict(w="fill", slots={"Labels": ruler_labels(n)}),
                   {"labels": [1, 9, 17, 25]}, slot="Labels")
song_map_component("BeatGrid", "beatgrid", lambda n, pdir: dict(w="fill", slots={"Bars": beatgrid_bars(n)}),
                   {"bars": 4}, slot="Bars")
song_map_component("Breadcrumb", "breadcrumb", lambda n, pdir: dict(w="fill", slots={"Items": breadcrumb_items(n)}),
                   {"items": ["Song", "Chorus 1", "b"]}, slot="Items")
song_map_component("SongMapTransport", "transport", lambda n, pdir: dict(w="fill", slots={"Controls": transport_controls(n)}),
                   {"speed": 75, "loop": True, "click": True}, slot="Controls")
song_map_component("SongMapOverview", "overview", i_timeline,
                   {"sections": [{"letter": "A", "bars": 9, "color": "section1"},
                                 {"letter": "B", "bars": 8, "color": "section2"},
                                 {"letter": "C", "bars": 12, "color": "section3", "state": "selected"}],
                    "playhead": .7, "cuts": [.8]}, slot="Timeline")
song_map_component("SongMapTimeline", "zoomwave", i_timeline,
                   {"title": "C · Chorus 1", "color": "section3", "startBar": 18, "playhead": .4,
                    "parts": [{"letter": "a", "bars": 4}, {"letter": "b", "bars": 4, "state": "selected"},
                              {"letter": "c", "bars": 4, "state": "candidate"}],
                    "cut": 2 / 3, "cutLabel": "bar 26"}, slot="Timeline")
comp("Key", ["key"], lambda v: {"t": "key", "v": "Shift", "icon": "keyboard_arrow_up", "lit": v["State"] == "Lit"},
     i_key, axes={"Mode": list(MODES.values()), "State": ["Idle", "Lit"]},
     props=[("Label", "text", "Label", None), ("Icon", "text", "Icon", None),
            ("Show icon", "boolean", "Icon", True)], main_w=96)


MAT = "package:flutter/material.dart"
APP = "package:flowgroove/widgets/"
# Code Connect: component -> (import, code name, flutter template, description). Templates are text:
# {Prop} is the instance's value; a variant renders as <Component><Prop>.<value> (e.g. ButtonVariant.primary,
# which is CustomButton's own enum); {Bool ? "a" : "b"} picks a literal.
CONNECT = {
    "CustomButton": (APP + "custom_button.dart", "CustomButton",
               'CustomButton(label: {Label}, variant: {Variant}, size: {Size},{Show icon ? " icon: Icons.add /* icon */," : ""} onPressed: () {})',
               "CustomButton. Primary = orange CTA, Secondary = white raised, Outline = OutlinedButton, Text = TextButton, "
               "Tonal = FilledButton.tonal (no border, no shadow), Danger = destructive (error red). Radius 5 (Radius/button). "
               "State: Default, Disabled (38% opacity), Loading (spinner glyph). Use it instead of raw ElevatedButton / OutlinedButton."),
    "FloatingActionButton": (MAT, "FloatingActionButton",
            'FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add /* icon */))',
            "FloatingActionButton (theme: white, charcoal 1.2 border, radius 6). Add actions only; orange is reserved for play/primary."),
    "IconButton": (MAT, "IconButton", 'IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert /* icon */))',
                   "Material IconButton, 48x48 hit area."),
    "AppFilterChip": (APP + "app_filter_chip.dart", "AppFilterChip",
             'AppFilterChip(label: {Label}, selected: {State} == ChipState.selected, onSelected: (_) {})',
             "AppFilterChip: filters and single choices. Selected = stone fill; Disabled = 38% opacity."),
    "UserAvatar": (APP + "user_avatar.dart", "UserAvatar", 'UserAvatar(photoURL: null, displayName: {Initials})',
               "UserAvatar / CircleAvatar: initials or an icon on surfaceOverlay."),
    "Switch": (MAT, "Switch", 'Switch(value: {State} == SwitchState.on, onChanged: (v) {})', "Material Switch."),
    "Checkbox": (MAT, "Checkbox", 'Checkbox(value: {State} == CheckboxState.on, onChanged: (v) {})', "Material Checkbox."),
    "CustomTextField": (APP + "custom_text_field.dart", "CustomTextField",
              'CustomTextField(label: {Show label ? "" : "null /* "}{Label}{Show label ? "" : " */"}, hint: {Value},'
              '{Show icon ? " prefixIcon: Icons.search /* icon */," : ""} maxLines: {Lines} == InputLines.multi ? 3 : 1)',
              "CustomTextField / TextField: white fill, radius 10 (MonoPulseRadius.medium). "
              "FigCraft variants use a 2px border and reserve a helper line. Focus uses accentOrange. "
              "Error uses error and shows the helper. Disabled uses 38% opacity."),
    "Slider": (MAT, "Slider", 'Slider(value: 0.5 /* {Value} */, onChanged: (v) {})', "Material Slider; Value variants in 10% steps."),
    "LinearProgressIndicator": (MAT, "LinearProgressIndicator", 'LinearProgressIndicator(value: 0.5 /* {Value} */)',
                 "LinearProgressIndicator; Value variants in 10% steps."),
    "Tab": (MAT, "Tab", 'Tab(text: {Label})', "TabBar tab: orange label + 3px indicator when selected."),
    "ButtonSegment": (MAT, "ButtonSegment", 'ButtonSegment(value: {Label}, label: Text({Label}))',
                "SegmentedButton / ToggleButtons segment."),
    "NavTab": (APP + "bottom_nav_or_action_bar.dart", "NavTab",
                'NavTab(item: (icon: Icons.home_outlined, selectedIcon: Icons.home, label: {Label}), '
                'selected: {State} == NavItemState.selected, onTap: () {})',
                "NavTab: one slot of AppBottomBar (main tabs, Back, Menu)."),
    "AppBottomBar": (APP + "bottom_nav_or_action_bar.dart", "AppBottomBar.actions",
                  'AppBottomBar.actions(onBack: () => context.pop(), title: {Show title ? "" : "null /* "}{Title}{Show title ? "" : " */"},'
                  '{Show primary ? " primaryAction: primaryButton," : ""}{Show menu ? " onMenu: openMenu," : ""})',
                  "AppBottomBar.actions: [Back] [title | primary action] [Menu], flex 1:2:1. Every pushed screen."),
    "ListTile": (MAT, "ListTile",
                 'ListTile(title: Text({Title}), subtitle: {Show subtitle ? "Text(" : "null /* "}{Subtitle}{Show subtitle ? ")" : " */"},'
                 '{Show leading ? " leading: /* Leading slot */ const Icon(Icons.circle)," : ""}'
                 '{Show trailing ? " trailing: /* Trailing slot */ const Icon(Icons.chevron_right)," : ""})',
                 "Material ListTile. Selected uses accentOrange10 background. Leading and Trailing are slots."),
    "SwitchListTile": (MAT, "SwitchListTile",
                  'SwitchListTile(title: Text({Title}), subtitle: {Show subtitle ? "Text(" : "null /* "}{Subtitle}{Show subtitle ? ")" : " */"}, '
                  'value: {State} == SwitchRowState.on, onChanged: (v) {})',
                  "SwitchListTile."),
    "AppBar": (MAT, "AppBar",
               'AppBar(title: Text({Title}), automaticallyImplyLeading: {Leading} == AppBarLeading.back, actions: [/* Actions slot */])',
               "AppBar: headlineLarge title on black. Actions is a slot of IconButtons."),
    "AppCard": (APP + "app_card.dart", "AppCard",
             'AppCard(variant: AppCardVariant.surface, child: /* {Direction}: Content slot */ const SizedBox())',
             "AppCard: surface, borderSubtle, radius 7 (Radius/card), padding 16. Content is a slot."),
    "ModalBottomSheet": (MAT, "ModalBottomSheet",
              'showModalBottomSheet(context: context, builder: (context) => /* {Docked}: Content slot */ const SizedBox())',
              "Bottom sheet surface: surfaceRaised, radius 16 top, grabber. Content is a slot."),
    "AppBadge": (APP + "app_badge.dart", "AppBadge",
              'AppBadge(label: {Label},{Show icon ? " icon: Icons.star /* icon */," : ""})',
              "AppBadge: pill label (band facts, status, offline). 10% tint of its colour, radius 20, 16 px icon."),
    "ChordChartView": (APP + "chord_chart_view.dart", "ChordChartView",
              'ChordChartView(chart: "[G]{Lyric} [D]grace")',
              "ChordPro chart rendered as chord labels above lyric syllables, with lines wrapping as needed."),
    "PerformanceSheetView": (APP + "performance_sheet_view.dart", "PerformanceSheetView",
              'PerformanceSheetView(sections: [Section(id: "section1", name: {Section}, chordChart: "[G]{Lyric} [D]grace")], bpm: 96)',
              "Performance sheet with section headings, chord-over-lyric rows, transpose controls and auto-scroll transport."),
    "LoadingIndicator": (APP + "loading_indicator.dart", "LoadingIndicator",
              'LoadingIndicator(message: {Message}, semanticsLabel: "Loading")',
              "Centered circular progress indicator with an optional message."),
    "ErrorBanner": (APP + "error_banner.dart", "ErrorBanner",
              'ErrorBanner(message: {Message}, title: {Title}, style: ErrorBannerStyle.{Style}, showRetry: true, onRetry: retry)',
              "Error feedback with error icon, title, message and optional retry action. Style selects banner, card or inline."),
    "QuickActionButton": (APP + "quick_action_button.dart", "QuickActionButton",
              'QuickActionButton(icon: Icons.add, label: {Label}, onTap: onTap)',
              "Raised quick action tile with orange icon and a two-line label."),
    "EmptyState": (APP + "empty_state.dart", "EmptyState",
              'EmptyState(icon: Icons.music_note, message: {Message}, hint: {Hint}, actionLabel: {Action}, onAction: onAction, secondaryActionLabel: {SecondaryAction}, onSecondaryAction: onSecondaryAction)',
              "Centered empty state with icon, message, optional hint and up to two outline actions."),
    "ToolButton": (APP + "tool_button.dart", "ToolButton",
              'ToolButton(icon: Icons.tune /* {Icon} */, label: {Label}, onTap: onTap)',
              "Tool tile with icon, label, and a reserved Soon badge when disabled."),
    "SingleFab": (APP + "fab_variants.dart", "SingleFab",
              'SingleFab(icon: Icons.add /* {Icon} */, onPressed: onPressed, tooltip: "Create", heroTag: "main_fab")',
              "Single floating action button with optional tooltip and hero tag."),
    "UnifiedFilterSortWidget": (APP + "unified_item/unified_filter_sort_widget.dart", "UnifiedFilterSortWidget",
              'UnifiedFilterSortWidget(currentSort: SortOption.manual /* {Sort} */, onSortChanged: onSortChanged, filterText: {Filter}, onFilterChanged: onFilterChanged, hintText: {Hint})',
              "Search field with sort dropdown for unified lists."),
    "ConfirmationDialog": (APP + "confirmation_dialog.dart", "ConfirmationDialog",
              'ConfirmationDialog(title: {Title}, message: {Message}, confirmLabel: {confirmLabel}, cancelLabel: {cancelLabel}, icon: Icons.warning_amber /* {Icon} */)',
              "Confirmation dialog with icon, explanatory text, cancel action and confirm action."),
    "TimeSignatureBlock": (APP + "metronome/time_signature_block.dart", "TimeSignatureBlock",
              'const TimeSignatureBlock()', "Beat and subdivision rows with step controls, mode glyphs and count badges."),
    "TempoControlCluster": (APP + "metronome/tempo_control_cluster.dart", "TempoControlCluster",
              'const TempoControlCluster()', "Tempo dial with four corner step buttons: coarse ±5 and repeatable fine ±1."),
    "StatCard": (APP + "stat_card.dart", "StatCard",
              'StatCard(icon: Icons.speed /* {Icon} */, label: {Label}, value: {Value}, color: MonoPulseColors.accentOrange)',
              "Raised statistic card with a colored icon, prominent value and supporting label."),
    "SongLibraryBlock": (APP + "metronome/song_library_block.dart", "SongLibraryBlock",
              'const SongLibraryBlock()', "Songs and setlists library action with an optional loaded song summary and clear action."),
    "SetlistSongRow": (APP + "setlist_song_row.dart", "SetlistSongRow",
              'SetlistSongRow(index: {Index}, song: song, savedTitle: {Title}, savedArtist: {Artist}, performers: {Performers}, isCurrent: {isCurrent})',
              "Setlist row with numbered leading column, song title and artist, optional performers and trailing metadata."),
    "SetlistBreakRow": (APP + "setlist_break_row.dart", "SetlistBreakRow",
              'SetlistBreakRow(breakType: "break", label: {Label})',
              "Raised, bordered setlist divider with a pause icon and section label."),
    "SectionCard": (APP + "practice/section_card.dart", "SectionCard",
              'SectionCard(section: section, queued: {Queued} == SectionCardQueued.nextBar)',
              "Playback section card with section name and state plus its chord chart when present."),
    "PrimaryActionBar": (APP + "primary_action_bar.dart", "PrimaryActionBar",
              'PrimaryActionBar(label: {Label}, onPressed: onPressed, secondaryAction: (label: {SecondaryLabel}, onPressed: onSecondary))',
              "Safe area bottom action bar with a full width primary button and optional secondary action."),
    "SectionHeader": (APP + "section_header.dart", "SectionHeader",
                      'SectionHeader({Title}, style: {Style},{Show action ? " actionLabel: " : " /* "}{Action}'
                      '{Show action ? ", onAction: onSeeAll," : " */"})',
                      "SectionHeader: Title = titleMedium section inside a screen; Label = quiet labelMedium group label."),
    "AlertDialog": (MAT, "AlertDialog",
               'AlertDialog(title: {Show title ? "Text(" : "null /* "}{Title}{Show title ? ")" : " */"}, '
               'content: /* Content slot */ null, actions: [/* Actions slot */])',
               "AlertDialog (ConfirmationDialog for confirms): surfaceRaised, radius 16. Destructive confirm = Danger button."),
    "SongMapTransport": ("package:flowgroove/screens/practice_regions/song_map/song_map_transport.dart", "SongMapTransport",
                  'SongMapTransport(playing: false, speedPercent: 100, loop: false, countIn: false, click: false, '
                  'clickAndDrums: false, onPlay: () {}, onStop: () {}, onSpeedTap: () {}, onLoopChanged: (_) {}, '
                  'onCountInChanged: (_) {}, onClickChanged: (_) {}, onClickAndDrumsChanged: (_) {})',
                  "Persistent Song Map playback controls."),
    "SongMapOverview": ("package:flowgroove/screens/practice_regions/song_map/song_map_timeline.dart", "SongMapOverview",
                 'SongMapOverview(entry: entry, view: songMapView)', "Whole-song Song Map overview."),
    "SongMapTimeline": ("package:flowgroove/screens/practice_regions/song_map/song_map_timeline.dart", "SongMapTimeline",
                 'SongMapTimeline(view: songMapView)', "Zoomed section waveform and timeline."),
    "SongMapPads": ("package:flowgroove/screens/practice_regions/song_map/song_map_pads.dart", "SongMapPads",
             'SongMapPads(view: songMapView)', "Song Map practice pads."),
    # ponytail: SongMapTempoBanner has no FigCraft component yet (banner is a frame), add its entry with one.
}
DESC_ONLY = {
    "SongCard": "Song list item with title, artist and key/tempo metadata.",
    "SetlistCard": "Setlist item with title, song count and optional date metadata.",
    "MemberCard": "Band member item with name, role and optional music-role metadata.",
    "StatusBar": "System status bar placeholder (not app code).",
    "SongMapPads": "Section or part launcher with an optional letter badge. Playing shows loop progress. Queued is marked next.",
    "SectionBlock": "Song timeline section. Repeats reuse a letter and colour. Dashed borders mark candidates.",
    "PartBlock": "Part lane block with a letter and bar count.",
    "Boundary": "Timeline seam handle. A dashed stem marks a candidate boundary.",
    "Playhead": "Playback position marker for a timeline overlay.",
    "Minimap": "Whole-song section strip with an outlined window for the current viewport.",
    "Ruler": "Evenly spaced bar labels for the visible timeline span.",
    "BeatGrid": "Visible bars divided into beats, with a taller tick on each downbeat.",
    "Breadcrumb": "Zoom path from Song to the current section or part.",
    "SongMapTransport": "Sticky playback controls with speed, loop, count-in, click and drums.",
    "SongMapOverview": "Whole-song waveform and letter lane on the same bar scale, with a playhead and dashed new cuts.",
    "SongMapTimeline": "Section waveform with a proportional parts lane, individual bar numbers and an optional labeled new cut.",
    "Key": "48 px MPC function key with an optional icon. Lit keys have an orange fill and charcoal text.",
}


def connect_components(reg):
    """Code Connect links + descriptions on each component set."""
    for cname, variants in reg.items():
        any_id = next(iter(variants.values()))
        if cname in CONNECT:
            imp, name, tpl, desc = CONNECT[cname]
            r = ex("codeConnect.set", {"id": any_id, "language": "flutter", "importPath": imp, "name": name,
                                       "template": tpl})
            if r.get("unknown"):
                raise ValueError(f"{cname}: unknown placeholders {r['unknown']}")
        else:
            desc = DESC_ONLY[cname]
        ex("node.set", {"ids": [TOPS.get(cname, any_id)], "props": {"description": desc}})


TOPS = {}  # cname -> component or set id (filled by build_components)


def pref(x):
    """A parent/target: an emit ref name, a ready {"$ref"} object, or a plain id."""
    return {"$ref": x} if isinstance(x, str) and re.fullmatch(r"n[0-9]+", x) else x


def use(e, cname, n, parent, pdir):
    """Place an instance of component `cname` for spec node `n`."""
    c = C[cname]
    spec = c["inst"](n, pdir)
    v = spec.get("v", {})
    if "Mode" in c["axes"]:
        v["Mode"] = MODES[e.mode]
    for a, vals in c["axes"].items():
        if v.get(a) not in vals:
            raise ValueError(f"{cname}: {a}={v.get(a)!r} not in {vals}")
    if not ONLINE:  # offline check: the mapping is valid; draw plain layers to validate the rest
        return MACROS[n["t"]](e, n, parent, pdir)
    # Draw custom child styling and geometry at creation time. Instance layers
    # inherit these from the main; icon glyphs already use text properties.
    if any(props.keys() - {"name"} for props in spec.get("over", {}).values()):
        raise Unsupported("custom child properties")
    lib = LIB[cname][vkey(c, v)]

    def L(name):
        if name not in lib["layers"]:
            raise ValueError(f"{cname}: no layer {name!r} in {vkey(c, v)}")
        return {"$ref": r, "field": f"map/{lib['layers'][name]}"}

    r = e.ref()
    if "name" in n:
        e.named_instances[len(e.cmds)] = n["name"]
    e.cmds.append({"command": "edit.duplicate", "params": {"ids": [lib["tpl"]], "map": True}, "as": r})
    me = {"$ref": r, "field": "ids/0"}
    e.cmds.append({"command": "node.reparent", "params": {"ids": [me], "parent": pref(parent)}})
    if spec.get("p"):
        e.cmds.append({"command": "instance.setProperties", "params": {"ids": [me], "properties": spec["p"]}})
    root = {"name": n.get("name", cname)}
    root.update(spec.get("root", {}))
    root.update(size_props({"w": n.get("w", spec.get("w")), "h": n.get("h", spec.get("h"))}, pdir))
    e.cmds.append({"command": "node.set", "params": {"ids": [me], "props": root}})
    e.cmds += bind_cmds(me, root)
    for name, props in spec.get("nested", {}).items():
        e.cmds.append({"command": "instance.setProperties", "params": {"ids": [L(name)], "properties": props}})
    slot_dir = {s: d for s, _, d in c["slots"]}
    slot_layer = {s: l for s, l, _ in c["slots"]}
    for sname, nodes in spec.get("slots", {}).items():
        d = slot_dir[sname]
        if d == "dir":
            d = "h" if v.get("Direction") == "Horizontal" else "v"
        children(e, nodes, L(slot_layer[sname]), d)
    return me


def outline_layers(node_id):
    """name -> id for the layers of a main or instance (not descending into nested instances)."""
    out = {}

    def walk(n, top):
        if not top:
            out.setdefault(n["name"], n["id"])
            if n.get("type") == "INSTANCE":
                return
            if n.get("childCount") and "children" not in n:  # outline stops two levels down
                n = ex("node.get", {"id": n["id"], "outline": True})
        for k in n.get("children", []):
            walk(k, False)
    walk(ex("node.get", {"id": node_id, "outline": True}), True)
    return out


def draw_variant(e, c, v):
    e.mode = v.get("Mode", "Dark").lower()
    e.drawing = set(c["types"]) | set(c["inline"])
    start = len(e.cmds)
    emit(e, c["draw"](v), None, "v")
    cmd = e.cmds[start]["params"]
    if cmd["props"].get("sizingH") == "fill":
        cmd["props"].update(sizingH="fixed", width=c["main_w"])
    if cmd["props"].get("sizingV") == "fill":
        cmd["props"]["sizingV"] = "hug"
    return cmd


def variant_dimensions(e):
    """Compare fixed sizes and intrinsic layout expressions without FigCraft's font engine."""
    children_by_parent = {}
    nodes = {}
    for cmd in e.cmds:
        if cmd["command"] != "node.create":
            continue
        ref, node = cmd["as"], cmd["params"]
        nodes[ref] = node
        parent = node.get("parent", {}).get("$ref")
        if not node["props"].get("absolute") and node["props"].get("visible", True):
            children_by_parent.setdefault(parent, []).append(ref)

    def size(ref, axis):
        node = nodes[ref]
        p = node["props"]
        key, sizing = ("width", "sizingH") if axis == 0 else ("height", "sizingV")
        if p.get(sizing) == "fill":
            return 0  # Assigned by the parent rather than contributing to its hug size.
        if key in p or key in node:
            return p.get(key, node.get(key))
        if node["type"] == "text":
            metrics = tuple(p.get(k) for k in
                            ("textStyle", "fontFamily", "fontStyle", "fontSize", "lineHeight", "letterSpacing"))
            if p.get("fontFamily") == "Material Icons":
                return p["fontSize"]  # Material glyphs share a square em box.
            content = node["text"]
            if axis == 1 and (p.get("maxLines") == 1 or p.get("textAutoResize") == "widthAndHeight"):
                content = content.count("\n") + 1 if p.get("maxLines") != 1 else 1
            return ("text", metrics, content, p.get("maxLines"), p.get("textAutoResize"))
        kids = [size(child, axis) for child in children_by_parent.get(ref, ())]
        pad = p.get("padding", 0)
        inset = pad[(1 - axis)] + pad[3 - axis] if isinstance(pad, list) else 2 * pad
        along = p.get("layout") == ("horizontal", "vertical")[axis]
        fixed = [k for k in kids if isinstance(k, (int, float))]
        intrinsic = [k for k in kids if not isinstance(k, (int, float))]
        if along:
            base = inset + sum(fixed) + p.get("gap", 0) * max(0, len(kids) - 1)
            return ("sum", base, tuple(intrinsic)) if intrinsic else base
        largest = max(fixed, default=0)
        if not intrinsic:
            return inset + largest
        return ("max", inset, largest, tuple(sorted(set(intrinsic), key=repr)))

    root, = children_by_parent[None]
    return size(root, 0), size(root, 1)


def check_component_dimensions():
    errors = []
    for cname, c in C.items():
        if not c["axes"]:
            continue
        groups = {}
        for v in combos(c):
            e = Emit()
            draw_variant(e, c, v)
            # Size, Lines and bottom-bar type describe different layouts, independently of state.
            group = (v.get("Size"), v.get("Lines"), v.get("Tab") == "Actions" if cname == "AppBottomBar" else None)
            groups.setdefault(group, {}).setdefault(variant_dimensions(e), []).append(vkey(c, v))
        for dimensions in groups.values():
            if len(dimensions) > 1:
                axes = [axis for i, axis in enumerate(("width", "height"))
                        if len({d[i] for d in dimensions}) > 1]
                variants = " vs ".join(" / ".join(names) for names in dimensions.values())
                errors.append(f"{cname}: variant {' and '.join(axes)} differ: {variants}")
    return errors


def build_components():
    """Draw every component's variants on the Components page and make them components."""
    ex("page.select", {"id": page_ids()[COMP_PAGE]})
    reg, y = {}, 0
    for cname, c in C.items():
        e = Emit()
        starts, vs = [], combos(c)
        for i, v in enumerate(vs):
            starts.append(len(e.cmds))
            cmd = draw_variant(e, c, v)
            cmd.update(x=(i % 6) * (c["main_w"] + 48), y=y + (i // 6) * 240, name=vkey(c, v) if c["axes"] else cname)
        res = ex("command.batch", {"label": f"Component {cname}", "commands": e.cmds, "onError": "abort"})
        ids = [res[i]["id"] for i in starts]
        for mode in c["axes"].get("Mode", []):
            ex("variable.setMode", {"ids": [i for i, v in zip(ids, vs) if v["Mode"] == mode],
                                    "collection": COL, "mode": mode})
        ex("component.createMultiple", {"ids": ids})
        top = ids[0]
        if c["axes"]:
            top = ex("component.combineVariants", {"ids": ids})["id"]
        ex("node.set", {"ids": [top], "props": {"name": cname}})
        TOPS[cname] = top
        lay = [outline_layers(i) for i in ids]
        for pname, ptype, layer, default in c["props"]:
            have = [l[layer] for l in lay if layer in l]
            if not have:
                raise ValueError(f"{cname}: property {pname} has no layer {layer!r}")
            a = {"id": top, "name": pname, "type": ptype, "layer": have[0]}
            if ptype == "boolean" and default is not None:
                a["default"] = default
            ex("component.addProperty", a)
            for lid in have[1:]:
                ex("component.bindProperty", {"layer": lid, "property": pname,
                                              "field": "visible" if ptype == "boolean" else "characters"})
        for sname, layer, _ in c["slots"]:
            have = [l[layer] for l in lay if layer in l]
            ex("component.makeSlot", {"id": have[0], "name": sname})
            for lid in have[1:]:  # one slot property per set; the other variants bind to it
                ex("component.bindProperty", {"layer": lid, "property": sname, "field": "slot"})
        reg[cname] = {vkey(c, v): i for v, i in zip(vs, ids)}
        add_templates(cname, reg[cname])
        b = ex("node.get", {"id": top, "fields": ["absoluteBounds"]})["absoluteBounds"]
        y = b["y"] + b["height"] + 120
        print(f"component {cname}: {len(ids)} variant(s)")
    json.dump(reg, open(CREG, "w"), indent=1)
    connect_components(reg)
    return reg


def add_templates(cname, variants):
    """Template instance per variant (deleted again by drop_lib) with its layer ids."""
    LIB[cname] = {}
    for k, main in variants.items():
        tpl = ex("instance.create", {"component": main, "x": -3000, "y": 0})["id"]
        LIB[cname][k] = {"tpl": tpl, "layers": outline_layers(tpl)}


def build_foundations():
    """Foundations page: colours (Dark and Light side by side), type scale, spacing and radius scales."""
    ex("page.select", {"id": page_ids()["Foundations"]})

    def swatch(name, hexes):
        return {"t": "row", "gap": 12, "cross": "center", "w": "fill", "c": [
            {"t": "box", "w": 44, "h": 44, "radius": 8, "bg": name, "border": "borderSubtle", "name": f"swatch/{name}"},
            {"t": "col", "gap": 2, "w": "fill", "c": [
                {"t": "text", "v": name, "style": "labelMedium"},
                {"t": "text", "v": hexes, "style": "caption", "color": "textTertiary"}]}]}

    def panel(title, mode):
        return {"t": "col", "name": f"Colours · {mode}", "bg": "black", "pad": 32, "gap": 12, "w": 420, "radius": 16,
                "border": "borderSubtle", "c": [{"t": "text", "v": title, "style": "headlineMedium"}] +
                [swatch(k, f"{d} / {l}") for k, (d, l) in PALETTE.items()]}

    brand = {"t": "col", "name": "Brand colours", "bg": "black", "pad": 32, "gap": 12, "w": 420, "radius": 16,
             "border": "borderSubtle", "c": [{"t": "text", "v": "Brand (both modes)", "style": "headlineMedium"},
                                             {"t": "row", "wrap": True, "gap": 12, "w": "fill", "c": [
                                                 {"t": "col", "gap": 4, "w": 80, "c": [
                                                     {"t": "box", "w": 80, "h": 40, "radius": 8, "bg": k, "border": "borderSubtle"},
                                                     {"t": "text", "v": k, "style": "caption", "color": "textSecondary"}]}
                                                 for k in BRAND]}]}
    type_scale = {"t": "col", "name": "Type scale", "bg": "black", "pad": 32, "gap": 14, "w": 520, "radius": 16,
                  "border": "borderSubtle", "c": [{"t": "text", "v": "Type (MonoPulseTypography)", "style": "headlineMedium"}] +
                  [{"t": "row", "gap": 16, "cross": "center", "w": "fill", "c": [
                      {"t": "text", "v": f"{k} · {fam} {size}", "style": "caption", "color": "textTertiary", "w": 170},
                      {"t": "text", "v": "Rehearse the bridge", "style": k, "w": "fill"}]} for k, (fam, sty, size, *_) in TYPE.items()]}
    space = {"t": "col", "name": "Spacing", "bg": "black", "pad": 32, "gap": 10, "w": 420, "radius": 16,
             "border": "borderSubtle", "c": [{"t": "text", "v": "Spacing (MonoPulseSpacing)", "style": "headlineMedium"}] +
             [{"t": "row", "gap": 12, "cross": "center", "w": "fill", "c": [
                 {"t": "text", "v": f"{k} · {v}", "style": "labelSmall", "color": "textSecondary", "w": 90},
                 {"t": "box", "w": v, "h": 16, "bg": "accentOrange", "name": f"space/{k}"}]} for k, v in SPACING.items()]}
    rad = {"t": "col", "name": "Radius", "bg": "black", "pad": 32, "gap": 16, "w": 420, "radius": 16,
           "border": "borderSubtle", "c": [{"t": "text", "v": "Radius (MonoPulseRadius + component)", "style": "headlineMedium"},
                                           {"t": "row", "wrap": True, "gap": 16, "w": "fill", "c": [
                                               {"t": "col", "gap": 6, "w": 76, "cross": "center", "c": [
                                                   {"t": "box", "w": 64, "h": 64, "radius": v, "bg": "surfaceRaised",
                                                    "border": "borderStrong", "name": f"radius/{k}"},
                                                   {"t": "text", "v": f"{k} {v}", "style": "caption", "color": "textSecondary",
                                                    "w": "hug"}]} for k, v in RADII.items()]}]}
    e = Emit()
    root = e.create("frame", None, "Foundations", {"fill": "none", "layout": "horizontal", "gap": 48, "crossAlign": "min",
                                                     "sizingH": "hug", "sizingV": "hug"})
    for n in (panel("Colours · Dark", "Dark"), panel("Colours · Light", "Light"), brand, type_scale, space, rad):
        emit(e, n, root, "h")
    # spacing bars take their width from the token too
    res = ex("command.batch", {"label": "Foundations", "commands": e.cmds, "onError": "abort"})
    light = ex("node.find", {"name": "Colours · Light", "type": "FRAME", "limit": 1})["ids"]
    ex("variable.setMode", {"ids": light, "collection": COL, "mode": "Light"})
    for k in SPACING:
        ids = ex("node.find", {"name": f"space/{k}", "limit": 1})["ids"]
        ex("variable.bind", {"ids": ids, "field": "width", "variable": VARS[f"Spacing/{k}"]})


def build_docs(reg, *, dryrun=False):
    """Docs page: one card per component -- description, properties, Flutter snippet, an instance."""
    ex("page.select", {"id": page_ids()["Docs"]})
    cards = []
    if not dryrun:
        rules = [
            "S1. Preserve size, padding, border width and text metrics across states. Change colour, fill, opacity or glyph. Reserve the widest border, with transparent ink when off.",
            "S2. Use tabular figures in fixed-width slots for time, BPM, counters and bar numbers. Reserve room for the largest label or indicator.",
            "S3. Repaint live data in reserved bounds. Keep the playhead inside the playing clip.",
            "S4. Reserve space or overlay appearing content. Animate reflow only for a user-tapped expand or collapse.",
            "S5. Align list columns with fixed slots. Keep the slot when a value is missing.",
        ]
        cards.append((None, None, {
            "t": "col", "name": "Doc/Stable layout", "bg": "surface", "border": "borderSubtle",
            "radius": 16, "pad": 24, "gap": 12, "w": 560, "c": [
                {"t": "text", "v": "Stable layout", "style": "headlineLarge"},
                *({"t": "text", "v": rule, "style": "bodySmall"} for rule in rules),
            ],
        }))
    for cname, variants in reg.items():
        any_id = next(iter(variants.values()))
        props = ex("component.properties", {"id": any_id})["properties"]
        rows = []
        for pr in props:
            if pr["type"] == "variant":
                val = " | ".join(pr["options"])
            elif pr["type"] == "slot":
                val = "slot"
            elif pr["type"] == "text" and len(str(pr.get("default", ""))) == 1 and ord(str(pr["default"])) > 0xE000:
                val = "text (Material icon glyph)"
            else:
                val = f'{pr["type"]}, default {pr.get("default")!r}'
            rows.append({"t": "row", "gap": 8, "w": "fill", "c": [
                {"t": "text", "v": pr["name"], "style": "labelSmall", "w": 120},
                {"t": "text", "v": val, "style": "caption", "color": "textSecondary", "w": "fill"}]})
        code = ""
        if cname in CONNECT:
            cc = ex("inspect.componentCode", {"id": any_id, "language": "flutter"})
            code = (cc.get("connected") or {}).get("code", "")
        desc = CONNECT[cname][3] if cname in CONNECT else DESC_ONLY[cname]
        cards.append((cname, any_id, {
            "t": "col", "name": f"Doc/{cname}", "bg": "surface", "border": "borderSubtle", "radius": 16, "pad": 24,
            "gap": 12, "w": 560, "c": [
                {"t": "text", "v": cname, "style": "headlineLarge"},
                {"t": "text", "v": desc, "style": "bodySmall", "color": "textSecondary"},
                {"t": "col", "name": "Preview", "bg": "black", "radius": 10, "pad": 16, "gap": 8,
                 "w": "fill", "cross": "min",
                 "c": []},
                {"t": "text", "v": "Properties", "style": "labelMedium", "color": "textTertiary"}] + rows + (
                [{"t": "text", "v": "Flutter (Code Connect)", "style": "labelMedium", "color": "textTertiary"},
                 {"t": "col", "bg": "blackSurface", "radius": 8, "pad": 12, "w": "fill",
                  "c": [{"t": "text", "v": code.strip(), "style": "mono", "color": "textSecondary"}]}] if code else
                [{"t": "text", "v": "No Code Connect link: no shared widget in lib/ yet.", "style": "caption",
                  "color": "warning"}])}))
    contrast_rows = [{"t": "row", "gap": 8, "w": "fill", "c": [
        {"t": "text", "v": f"{mode} · {kind}", "style": "caption", "w": 150},
        {"t": "text", "v": f"{fg} on {bg}", "style": "caption", "w": 200},
        {"t": "text", "v": f"{value:.2f}:1 (min {minimum:.1f})" + (" · decorative" if not required else ""),
         "style": "caption", "color": "textSecondary", "w": "fill"}]} for mode, kind, fg, bg, value, minimum, required in contrast_matrix()]
    cards.append((None, None, {"t": "col", "name": "Doc/Contrast", "bg": "surface", "border": "borderSubtle",
        "radius": 16, "pad": 24, "gap": 12, "w": 560, "c": [
            {"t": "text", "v": "Contrast", "style": "headlineLarge"},
            {"t": "text", "v": "Text pairs use WCAG 4.5:1; UI pairs use 3.0:1. Decorative pairs are informational.",
             "style": "bodySmall", "color": "textSecondary"},
            {"t": "text", "v": "Touch targets: minimum 48×48 dp.", "style": "bodySmall"}] + contrast_rows}))
    e = Emit()
    root = e.create("frame", None, "Component docs", {"fill": "none", "layout": "horizontal", "wrap": True,
                                                        "gap": 32, "crossGap": 32, "width": 1840,
                                                        "sizingH": "fixed", "sizingV": "hug"}, w=1840)
    previews = []
    for cname, any_id, card in cards:
        start = len(e.cmds)
        emit(e, card, root, "h")
        if cname is None:
            continue
        # the Preview frame is the 4th create of the card
        prev = [c["as"] for c in e.cmds[start:] if c["command"] == "node.create" and c["params"].get("name") == "Preview"][0]
        if cname is not None:
            previews.append((cname, prev))
    res = ex("command.batch", {"label": "Docs", "commands": e.cmds, "onError": "abort"})
    ref_id = {c["as"]: r.get("id") for c, r in zip(e.cmds, res) if c.get("as") and isinstance(r, dict)}
    for cname, prev in previews:
        c = C[cname]
        if "Mode" not in c["axes"]:
            v = next(iter(reg[cname].values()))
            ex("instance.create", {"component": v, "parent": ref_id[prev]})
            continue
        for mode in MODES:
            e = Emit(mode)
            values = {axis: options[0] for axis, options in c["axes"].items()}
            values["Mode"] = MODES[mode]
            sample = c["draw"](values)
            sample.pop("_slots", None)
            panel = e.create("frame", ref_id[prev], MODES[mode], {
                "fill": color("black"), "layout": "vertical", "padding": 8, "gap": 4,
                "sizingH": "fill", "sizingV": "hug"})
            m_text(e, {"v": MODES[mode], "style": "caption"}, panel, "v")
            emit(e, sample, panel, "v")
            result = ex("command.batch", {"label": f"{cname} · {MODES[mode]}", "commands": e.cmds, "onError": "abort"})
            ex("variable.setMode", {"ids": [result[0]["id"]], "collection": COL, "mode": MODES[mode]})


def export_connect(out=None):
    out = out or os.path.join(HERE, "figcraft.connect.json")
    links_by_name = dict(CONNECT)
    for name in USED_ICONS:
        links_by_name[f"Icon/{name}"] = (MAT, "Icon", f"const Icon(Icons.{name})", f"Material icon {name}.")
    links = [{"component": cname, "importPath": imp, "language": "flutter", "name": name, "template": tpl}
             for cname, (imp, name, tpl, _) in links_by_name.items()]
    json.dump({"links": sorted(links, key=lambda x: x["component"]), "version": 1}, open(out, "w"), indent=2)
    return out


def build_icons_page():
    """Build one swappable Material glyph component per name in icons.txt."""
    ex("page.select", {"id": page_ids()["Icons"]})
    e, starts = Emit(), []
    for i, name in enumerate(USED_ICONS):
        x, y = (i % 10) * 112, (i // 10) * 100
        start = len(e.cmds)
        frame = e.create("frame", None, f"Icon/{name}", {
            "fill": "none", "layout": "vertical", "crossAlign": "center", "gap": 6,
            "padding": 8, "width": 96, "height": 88, "sizingH": "fixed", "sizingV": "fixed"})
        e.cmds[start]["params"].update(x=x, y=y)  # the create; later cmds are token binds
        m_icon(e, {"v": name, "size": 24}, frame, "v")
        m_text(e, {"v": name, "style": "caption", "color": "textPrimary", "w": "hug"}, frame, "v")
        starts.append((start, name))
    res = ex("command.batch", {"label": "Icons page", "commands": e.cmds, "onError": "abort"})
    ids = [res[index]["id"] for index, _ in starts]
    ex("component.createMultiple", {"ids": ids})
    for (_, name), cid in zip(starts, ids):
        ex("component.addProperty", {"id": cid, "name": "Icon", "type": "text", "layer": f"icon/{name}"})
        ex("codeConnect.set", {"id": cid, "language": "flutter", "importPath": MAT, "name": "Icon",
                                "template": f"const Icon(Icons.{name})"})


def load_lib():
    VARS.update(json.load(open(TOKENS)))
    ex("page.select", {"id": page_ids()[COMP_PAGE]})
    for cname, variants in json.load(open(CREG)).items():
        add_templates(cname, variants)


def drop_lib():
    ids = [v["tpl"] for c in LIB.values() for v in c.values()]
    if ids:
        ex("edit.delete", {"ids": ids})
    LIB.clear()


# ---------------------------------------------------------------- document
PAGES = ["Foundations", "Components", "Docs", "Icons", "Auth", "Home & Tools", "Songs", "Setlists", "Bands", "Settings",
         "Sheets & Dialogs", "Parity", "Song Map"]


def page_ids():
    return {p["name"]: p["id"] for p in ex("page.list")}


RADIUS_NOTES = {"button": "Button radius (theme + CustomButton)", "fab": "FAB radius",
                "card": "AppCard radius", "cardMaterial": "Material Card theme radius"}


def text_style_value(fam, sty, size, height, spacing):
    v = {"fontFamily": fam, "fontStyle": sty, "fontSize": size}
    if height:
        v["lineHeight"] = {"unit": "percent", "value": round(height * 100, 2)}
    if spacing:
        v["letterSpacing"] = {"unit": "pixels", "value": spacing}
    return v


def push_tokens():
    """tokens.json -> variables + text styles in the open (fresh) document. Fills VARS."""
    cmds, n = [{"command": "variable.createCollection", "params": {"name": COL, "modes": ["Dark", "Light"]}}], 0

    def var(params, code):
        nonlocal n
        n += 1
        cmds.append({"command": "variable.create", "params": params, "as": f"v{n}"})
        cmds.append({"command": "variable.update", "params": {
            "variable": {"$ref": f"v{n}", "field": "id"}, "codeSyntax": {"ANDROID": code}}})

    for k, (d, l) in PALETTE.items():
        var({"collection": COL, "name": k, "type": "color", "values": {"Dark": d, "Light": l},
             "description": f"context.mp.{k}"}, f"context.mp.{k}")
    for k, v in BRAND.items():
        al = TOK["color"][k].get("alias")
        # an alias stays an alias in FigCraft, so editing its target moves it too. A palette target
        # means the fixed *dark* MonoPulseColors constant in Dart, so only the Dark mode aliases.
        vals = {"Dark": {"alias": al}, "Light": v if al in PALETTE else {"alias": al}} if al else \
            {"Dark": v, "Light": v}
        var({"collection": COL, "name": k, "type": "color", "values": vals,
             "description": f"MonoPulseColors.{k}" + (f" = {al}" if al else "")}, f"MonoPulseColors.{k}")
    for k, (fam, sty, size, height, spacing) in TYPE.items():
        cmds.append({"command": "style.create", "params": {
            "type": "text", "name": f"Type/{k}", "value": text_style_value(fam, sty, size, height, spacing),
            "description": "design-only (docs pages)" if k in DOC_TYPE else f"MonoPulseTypography.{k}"}})
    ex("command.batch", {"label": "Design tokens", "commands": cmds})
    cmds, names, n = [], [], 0
    for coll, key, cls in NUMBER_COLLS:
        cmds.append({"command": "variable.createCollection", "params": {"name": coll}})
        for k, v in TOK[key].items():
            note = f"{cls}.{k}" + (f" ({RADIUS_NOTES[k]})" if coll == "Radius" and k in RADIUS_NOTES else "")
            var({"collection": coll, "name": k, "type": "number", "value": v, "description": note}, f"{cls}.{k}")
            names.append(f"{coll}/{k}")
    res = ex("command.batch", {"label": "Number tokens", "commands": cmds})
    ids = [r["id"] for r in res if isinstance(r, dict) and str(r.get("id", "")).startswith("VariableID")
           and "codeSyntax" not in r]
    ids = list(dict.fromkeys(ids))  # create + update both echo the id
    assert len(ids) == len(names), (len(ids), len(names))
    VARS.clear()
    VARS.update(zip(names, ids))


def setup():
    for f in (REG, CREG):
        if os.path.exists(f):
            os.remove(f)
    ex("file.new", {"name": "FlowGroove Screens"})
    first = ex("page.list")[0]["id"]
    ex("page.rename", {"id": first, "name": "Cover"})
    for p in PAGES:
        ex("page.add", {"name": p})
    ids = page_ids()
    for pid in ids.values():
        ex("page.setBackground", {"id": pid, "color": "#141413"})
    push_tokens()
    json.dump(VARS, open(TOKENS, "w"), indent=1)


def scratch_run(job):
    """Run a full rebuild (`setup`, `all`) in a NEW scratch document, never in the working one.

    `file.new` opens a blank document, so the builder's frame/component/token indexes (REG, CREG,
    TOKENS) of the document that was open would be lost. The job writes its own indexes into a
    `.scratch` directory next to them, nothing is saved or published, and the document that was
    active before is made active again, whatever happens. The scratch document stays open and
    unsaved: inspect it, then close it (doc.switch, file.markSaved, file.close).
    """
    global REG, CREG, TOKENS
    home = next((d for d in ex("doc.list") if d.get("active")), None)
    if home is None:
        raise RuntimeError("no active document to return to; open the working document first")
    scratch = os.path.join(os.path.dirname(REG), ".scratch")
    os.makedirs(scratch, exist_ok=True)
    kept = REG, CREG, TOKENS
    print(f"working document: {home['name']!r} ({home.get('path') or 'unsaved'}): its indexes stay untouched")
    print(f"building into a NEW scratch document; scratch indexes in {scratch}")
    REG, CREG, TOKENS = (os.path.join(scratch, os.path.basename(f)) for f in kept)
    try:
        return job(scratch)
    finally:
        REG, CREG, TOKENS = kept
        docs = ex("doc.list")
        back = next((d for d in docs if (home.get("path") and d.get("path") == home["path"])
                     or (not home.get("path") and d.get("id") == home["id"])), None)
        if back is None:
            print(f"WARNING: the working document {home['name']!r} is no longer open")
        else:
            ex("doc.switch", {"index": back["index"]})
            scratch_docs = [d for d in docs if d["id"] != back["id"] and not d.get("path")]
            print(f"active document again: {back['name']!r} ({back.get('path') or 'unsaved'}); "
                  f"scratch document(s) left open, unsaved: {[d['index'] for d in scratch_docs]}")


SLOTS = {}  # page -> next index
REG = os.path.join(HERE, ".frames.json")  # spec name -> frame id in the open document
MAIN_NAV = {"Home": "Home", "Songs": "Songs", "Bands": "My bands", "Setlists": "Setlists",
            "More": "App menu sheet sheet L53"}


def spec_links(spec):
    links = list(spec.get("links", []))
    # The main shell's five destinations are stable shared navigation affordances.
    for node in spec.get("bottom", []):
        if isinstance(node, dict) and node.get("t") == "bottomnav":
            links.extend({"from": label, "to": MAIN_NAV[label]} for label, _ in NAV_TABS)
    return links


def load_reg():
    try:
        return json.load(open(REG))
    except (OSError, ValueError):
        return {}


def place(page, idx):
    cols = 6  # each slot leaves room on the right for the real-app screenshot (build.py parity)
    return (idx % cols) * (2 * W + 200), (idx // cols) * (H + 200)


def screen_mode(spec):
    mode = spec.get("mode", "dark")
    if mode not in MODES:
        raise ValueError("mode must be light or dark")
    return mode


def build_screen(spec):
    mode = screen_mode(spec)
    ids = page_ids()
    page = spec.get("page", "Home & Tools")
    if page not in ids:
        raise ValueError(f"unknown page {page!r}; one of {PAGES}")
    ex("page.select", {"id": ids[page]})
    reg = load_reg()
    if spec["name"] in reg:  # rebuild: drop the previous frame
        try:
            ex("edit.delete", {"ids": [reg[spec["name"]]]})
        except RuntimeError:
            pass
    idx = spec.get("slot", SLOTS.get(page, 0))
    SLOTS[page] = idx + 1
    x, y = place(page, idx)
    e = Emit(mode)
    root = e.ref()
    e.cmds.append({"command": "node.create", "as": root, "params": {
        "type": "frame", "x": x, "y": y, "width": W, "height": H, "name": spec["name"], "select": False,
        "props": {"fill": color(spec.get("bg", "black")), "layout": "vertical", "clip": True,
                  "sizingH": "fixed", "sizingV": "fixed"}}})
    emit(e, {"t": "statusbar", "bg": spec.get("statusBg", spec.get("bg", "black"))}, root, "v")
    for n in spec.get("top", []):
        emit(e, n, root, "v")
    body = {"t": "col", "name": "Body", "h": "fill", "w": "fill", "clip": True,
            "gap": spec.get("gap", 0), "pad": spec.get("pad", 0), "bg": spec.get("bodyBg", "none"),
            "c": spec.get("body", [])}
    modal = spec.get("modal")  # sheet | dialog: scrim, sheet docked at bottom, dialog centred
    if modal:
        body.update(bg="#000000B3", main="max" if modal == "sheet" else "center",
                    pad=0 if modal == "sheet" else [24, 24, 24, 24], name="Scrim")
    emit(e, body, root, "v")
    for n in spec.get("bottom", []):
        if isinstance(n, dict) and n.get("t") == "bottomnav":
            # Each tab needs its own instance root to attach a screen-specific link.
            m_bottomnav(e, n, root, "v")
        else:
            emit(e, n, root, "v")
    res = ex("command.batch", {"label": spec["name"], "commands": e.cmds, "onError": "abort"})
    root_id = res[0]["id"]
    if "mode" in spec:
        ex("variable.setMode", {"ids": [root_id], "collection": COL, "mode": MODES[mode]})
    # Keep the concrete source node ids with the screen's declared prototype links.
    node_ids = {}
    for i, (cmd, result) in enumerate(zip(e.cmds, res)):
        if i in e.named_instances:
            node_ids[e.named_instances[i]] = result["ids"][0]
        name = cmd.get("params", {}).get("name")
        if name and isinstance(result, dict) and result.get("id"):
            node_ids[name] = result["id"]
    for o in spec.get("overlay", []):  # absolutely positioned layers (FAB, sheets, scrims)
        oe = Emit(mode)
        r = emit(oe, o["node"], root_id, "v")
        oe.cmds.append({"command": "node.set", "params": {
            "ids": [pref(r)], "props": {"absolute": True, "x": o.get("x", 0), "y": o.get("y", 0)}}})
        ex("command.batch", {"label": spec["name"] + " overlay", "commands": oe.cmds})
    reg[spec["name"]] = root_id
    json.dump(reg, open(REG, "w"), indent=1)
    return root_id, len(e.cmds), node_ids


def apply_links(links, frame_ids, node_ids):
    """Connect named screen nodes to already-built destination frames."""
    for source, target in links:
        source_id = node_ids.get(source, source)
        ex("proto.interaction.add", {"id": source_id, "trigger": {"type": "onClick"},
                                     "action": {"type": "navigate", "dest": frame_ids[target]}})


def export_png(node_id, path, scale=1):
    return ex("file.export", {"ids": [node_id], "format": "png", "scale": scale, "path": path})


GITHUB = "https://github.com/berlogabob/flutter-FlowGroove-app/blob/second01/"
WEB_APP = "https://app.flowgroove.app/#"  # hash URL strategy (no usePathUrlStrategy in lib/)
REAL = os.path.join(HERE, "..", "real")
RENDER = os.path.join(HERE, "..", "render")


def real_png(key: str, spec: dict) -> str | None:
    render = os.path.join(RENDER, f"{key}@{screen_mode(spec)}-412-1.00.png")
    fallback = os.path.join(REAL, f"{key}.png")
    return next((path for path in (render, fallback) if os.path.exists(path)), None)


def parity_note(key: str) -> str:
    path = os.path.join(RENDER, "parity.json")
    if not os.path.exists(path):
        return "parity: unavailable"
    with open(path) as f:
        result = json.load(f).get(key)
    if result is None:
        return "parity: unavailable"
    if result.get("pass") is True:
        return "parity pass"
    return (f"parity: missing {len(result.get('missing', []))}, "
            f"extra {len(result.get('extra', []))}, order {result.get('order', 0):.2f}")


def rmse(a, b):
    """Root-mean-square difference of two screenshots, 0 (same) .. 100, at a coarse 206 px width."""
    tmp = [os.path.join(HERE, "logs", f".rmse{i}.png") for i in (0, 1)]
    for src, dst in zip((a, b), tmp):
        subprocess.run(["magick", src, "-alpha", "off", "-resize", "206x458!", dst], check=True)
    r = subprocess.run(["magick", "compare", "-metric", "RMSE", *tmp, "null:"], capture_output=True, text=True)
    m = re.search(r"\(([\d.e-]+)\)", r.stderr)
    if not m:
        raise RuntimeError(f"compare: {r.stderr.strip()}")
    return round(float(m.group(1)) * 100, 1)


def parity(dryrun=False):
    """Link every screen frame to its code, and put each captured real screen beside its frame."""
    reg = load_reg()
    index = json.load(open(os.path.join(REAL, "index.json"))) if os.path.exists(os.path.join(REAL, "index.json")) else {}
    if not dryrun:
        os.makedirs(os.path.join(HERE, "logs"), exist_ok=True)
    pages, rows = page_ids(), []
    for path in sorted(glob.glob(os.path.join(HERE, "specs", "*.json"))):
        key, spec = os.path.basename(path)[:-5], json.load(open(path))
        fid = reg.get(spec["name"])
        if not fid:
            continue
        try:
            ex("node.get", {"id": fid, "fields": ["x"]})
        except RuntimeError:  # frame gone (a failed rebuild deleted it): rebuild that screen first
            print(f"skip {key}: frame {fid} not in the document")
            continue
        try:
            ex("devResource.remove", {"id": fid})
        except RuntimeError:
            pass
        if spec.get("source"):
            src, _, line = spec["source"].partition(":")
            ex("devResource.add", {"id": fid, "url": GITHUB + src + (f"#L{line}" if line else ""),
                                   "name": "Flutter source"})
        route = spec.get("route")
        if route and "{" not in route:
            ex("devResource.add", {"id": fid, "url": WEB_APP + route, "name": "Open in web app"})
        for old in (reg.pop(f"real:{spec['name']}", None), reg.pop(f"realnote:{spec['name']}", None)):
            if old:
                try:
                    ex("edit.delete", {"ids": [old]})
                except RuntimeError:
                    pass
        png = real_png(key, spec)
        ex("node.set", {"ids": [fid], "devStatus":
                        "readyForDev" if parity_note(key) == "parity pass" else None})
        if not png:
            rows.append((None, spec, key, route))
            continue
        ex("page.select", {"id": pages[spec.get("page", "Home & Tools")]})
        pos = ex("node.get", {"id": fid, "fields": ["x", "y"]})
        design = os.path.join(HERE, "logs", f".{key}.design.png")
        meta = index.get(key, {})
        mode = (MODES[screen_mode(spec)] if os.path.dirname(png) == RENDER else
                "Dark" if meta.get("night", "").endswith("yes") else "Light")
        ex("variable.setMode", {"ids": [fid], "collection": COL, "mode": mode})
        export_png(fid, design)
        ex("variable.setMode", {"ids": [fid], "collection": COL, "mode": MODES[screen_mode(spec)]})
        score = 0.0 if dryrun else rmse(design, png)
        img = ex("image.place", {"path": os.path.abspath(png), "x": pos["x"] + W + 40, "y": pos["y"],
                                 "width": W, "name": f"Real · {spec['name']}"})
        note = ex("node.create", {"type": "text", "x": pos["x"] + W + 40, "y": pos["y"] + img["height"] + 12,
                                  "width": W, "select": False, "name": f"Parity · {spec['name']}",
                                  "text": f"{parity_note(key)} · diff {score} · {meta.get('route', route)} · "
                                          f"{meta.get('device', '?')} · {meta.get('captured', '?')[:10]}",
                                  "props": {"textStyle": "Type/caption", "fill": "#D8D6CC"}})
        reg[f"real:{spec['name']}"], reg[f"realnote:{spec['name']}"] = img["id"], note["id"]
        rows.append((score, spec, key, route))
    json.dump(reg, open(REG, "w"), indent=1)
    parity_page(rows, pages)
    return rows


def parity_page(rows, pages):
    if "Parity" not in pages:
        ex("page.add", {"name": "Parity"})
        pages = page_ids()
    ex("page.select", {"id": pages["Parity"]})
    old = load_reg().get("parity:table")
    if old:
        try:
            ex("edit.delete", {"ids": [old]})
        except RuntimeError:
            pass
    rows = sorted(rows, key=lambda r: (r[0] is None, parity_note(r[2]) == "parity pass", -(r[0] or 0)))
    done = sum(r[0] is not None for r in rows)
    ok = sum(parity_note(r[2]) == "parity pass" for r in rows)
    lines = [f"Parity: {done} of {len(rows)} screens captured, {ok} passing (readyForDev) · "
             "results in design/render/parity.json · build.py parity", ""]
    for score, spec, key, route in rows:
        s = "  —  " if score is None else f"{score:5.1f}"
        v = parity_note(key)
        lines.append(f"{s}  {spec['name'][:28]:28}  {(route or 'no route')[:44]:44}  {v[:90]}")
    t = ex("node.create", {"type": "text", "x": 0, "y": 0, "width": 1400, "select": False, "name": "Parity table",
                           "text": "\n".join(lines), "props": {"textStyle": "Type/mono", "fill": "#F6F5F0"}})
    reg = load_reg()
    reg["parity:table"] = t["id"]
    json.dump(reg, open(REG, "w"), indent=1)


def matrix(keys):
    """Place the render matrix in allCells order, including missing cells."""
    pages = page_ids()
    if "Matrix" not in pages:
        ex("page.add", {"name": "Matrix"})
        pages = page_ids()
    ex("page.select", {"id": pages["Matrix"]})
    reg = load_reg()
    for node in reg.get("matrix:nodes", []):
        try:
            ex("edit.delete", {"ids": [node]})
        except RuntimeError:
            pass
    status_path = os.path.join(RENDER, "matrix.json")
    if os.path.exists(status_path):
        with open(status_path) as f:
            statuses = json.load(f)
    else:
        statuses = {}
    nodes = []
    for row, key in enumerate(keys):
        cells = (f"{key}@{theme}-{width}-{scale:.2f}"
                 for theme in ("light", "dark") for width in (360, 393, 412, 420)
                 for scale in (1.0, 1.3))
        for col, cell in enumerate(cells):
            x, y = col * 230, row * 550
            png = os.path.join(RENDER, cell + ".png")
            if os.path.exists(png):
                img = ex("image.place", {"path": os.path.abspath(png), "x": x, "y": y,
                                         "width": 200, "name": cell})
                nodes.append(img["id"])
            caption = ex("node.create", {"type": "text", "x": x, "y": y + 490,
                                        "width": 220, "select": False, "name": cell,
                                        "text": f"{cell} · {statuses.get(cell, 'missing')}",
                                        "props": {"textStyle": "Type/caption", "fill": "#F6F5F0"}})
            nodes.append(caption["id"])
    reg["matrix:nodes"] = nodes
    with open(REG, "w") as f:
        json.dump(reg, f, indent=1)


def _hex(c):
    h = "#" + "".join(f"{round(c[k] * 255):02X}" for k in "rgb")
    a = round(c.get("a", 1) * 255)
    return h if a == 255 else h + f"{a:02X}"


def doc_tokens():
    """The open document's variables + text styles, folded back onto tokens.json (a copy).

    Returns (tokens, notes): changed values overwrite, new variables are added, variables missing
    from the document are reported in notes and kept (deleting one would break the code build).
    """
    tok = json.loads(json.dumps(TOK))
    lst = ex("variable.list", {})
    colls = {c["id"]: c for c in lst["collections"]}
    names = {v["id"]: v["name"] for v in lst["variables"]}
    seen, notes = set(), []
    groups = {coll: key for coll, key, _ in NUMBER_COLLS}
    for v in lst["variables"]:
        c = colls[v["collection"]]
        if c.get("remote"):
            continue
        modes = {m["id"]: m["name"] for m in c["modes"]}
        raw = {modes[mid]: x for mid, x in v["values"].items()}
        vals = {m: x["value"] for m, x in raw.items() if x.get("type") != "alias"}
        name = v["name"]
        if c["name"] == COL:
            seen.add(("color", name))
            if name in tok["palette"]:
                dark = _hex(vals["Dark"])
                tok["palette"][name] = {"dark": dark, "light": _hex(vals["Light"])}
                if "value" in tok["color"].get(name, {}):  # Dart's dark palette reads MonoPulseColors.<name>
                    tok["color"][name]["value"] = dark
                continue
            e = tok["color"].get(name)
            keep = {"note": e["note"]} if e and e.get("note") else {}
            if raw["Dark"].get("type") == "alias":
                tok["color"][name] = {"alias": names[raw["Dark"]["value"]], **keep}
            else:
                tok["color"][name] = {"value": _hex(vals["Dark"]), **keep}
            if e is None:
                notes.append(f"added colour {name}")
        elif c["name"] in groups:
            key = groups[c["name"]]
            seen.add((key, name))
            val = next(iter(vals.values()))
            val = int(val) if float(val).is_integer() else val
            if name not in tok[key]:
                notes.append(f"added {c['name']}/{name} = {val}")
            tok[key][name] = val
    for name in [k for k in tok["palette"]] + [k for k in tok["color"]]:
        if ("color", name) not in seen:
            notes.append(f"colour {name} is not in the document (kept)")
    for coll, key, _ in NUMBER_COLLS:
        for name in tok[key]:
            if (key, name) not in seen:
                notes.append(f"{coll}/{name} is not in the document (kept)")
    fam_key = {v: k for k, v in FAMILY.items()}
    for st in ex("style.list", {"type": "text"}):
        name = st["name"].removeprefix("Type/")
        if name not in tok["type"]:
            continue
        x, t = st["style"], tok["type"][name]
        if x["font_family"] in fam_key:
            t["family"] = fam_key[x["font_family"]]
        t["size"] = int(x["font_size"]) if float(x["font_size"]).is_integer() else x["font_size"]
        lh = x.get("line_height") or {}
        if lh.get("unit") == "percent":
            t["height"] = round(lh["value"] / 100, 4)
        ls = x.get("letter_spacing") or {}
        if ls.get("unit") == "pixels" and ls.get("value"):
            t["letterSpacing"] = ls["value"]
        elif "letterSpacing" in t and not ls.get("value"):
            del t["letterSpacing"]
    return tok, notes


def token_diff(a, b, path=""):
    if isinstance(a, dict) and isinstance(b, dict):
        out = []
        for k in sorted(set(a) | set(b)):
            out += token_diff(a.get(k), b.get(k), f"{path}/{k}" if path else k)
        return out
    if isinstance(a, float) or isinstance(b, float):
        if a is not None and b is not None and abs(float(a) - float(b)) < 1e-3:
            return []
    return [] if a == b else [f"{path}: {a!r} -> {b!r}"]


REPO = os.path.abspath(os.path.join(HERE, "..", ".."))


def _lower_camel(v):
    w = re.split(r"[^0-9A-Za-z]+", v)
    return w[0][:1].lower() + w[0][1:] + "".join(x[:1].upper() + x[1:] for x in w[1:])


def template_args(tpl):
    """Named arguments at the top level of a Code Connect call template (placeholders transparent)."""
    body = re.sub(r"/\*.*?\*/", "", tpl[tpl.index("(") + 1:])
    body = body.replace("{", "").replace("}", "")
    depth, out = 0, []
    for m in re.finditer(r"[()\[\]]|\b(\w+):", body):
        t = m.group(0)
        if t in "([":
            depth += 1
        elif t in ")]":
            depth -= 1
        elif depth == 0:
            out.append(m.group(1))
    return out


def dart_ctor_params(src, ctor):
    """Parameter names of `ctor` (`Name` or `Name.named`) in Dart source, or None if not found."""
    base = ctor.split(".")[0]
    cls = re.search(rf"^class {base}\b[^{{]*\{{", src, re.M)
    if not cls:
        return None
    m = re.compile(rf"^\s*(?:const\s+)?{re.escape(ctor)}\s*\(", re.M).search(src, cls.end())
    if not m:
        return None
    i, depth = m.end(), 1
    while depth:
        depth += {"(": 1, ")": -1}.get(src[i], 0)
        i += 1
    sig = re.sub(r"//.*", "", src[m.end():i - 1])
    names = set(re.findall(r"(?:this|super)\.(\w+)", sig))
    names |= set(re.findall(r"[\w<>?,\s]+?\s(\w+)\s*(?:=|,|\}|$)", sig))
    return names


def verify_components():
    """Code Connect templates and FigCraft variants vs the Dart widgets they link to. Offline."""
    errors, checked = [], 0
    expected = {"actionbar": "AppBottomBar", "bottomnav": "AppBottomBar", "avatar": "UserAvatar",
                "badge": "AppBadge", "button": "CustomButton", "card": "AppCard", "chip": "AppFilterChip",
                "dialog": "AlertDialog", "fab": "FloatingActionButton", "input": "CustomTextField",
                "navitem": "NavTab", "progress": "LinearProgressIndicator", "segment": "ButtonSegment",
                "sheet": "ModalBottomSheet", "switchrow": "SwitchListTile", "pad": "SongMapPads",
                "transport": "SongMapTransport", "overview": "SongMapOverview", "zoomwave": "SongMapTimeline"}
    for node_type, component in expected.items():
        if TYPE2COMP.get(node_type) != component:
            errors.append(f"{node_type}: expected component {component}, got {TYPE2COMP.get(node_type)}")
    for cname, (imp, name, tpl, _desc) in CONNECT.items():
        if not imp.startswith("package:flowgroove/"):
            continue  # Material widget: the SDK is the contract
        path = os.path.join(REPO, "lib", imp[len("package:flowgroove/"):])
        if not os.path.exists(path):
            errors.append(f"{cname}: {path} does not exist")
            continue
        src = open(path).read()
        params = dart_ctor_params(src, name)
        if params is None:
            errors.append(f"{cname}: constructor {name}( not found in {imp}")
            continue
        for arg in template_args(tpl):
            if arg not in params:
                errors.append(f"{cname}: template passes `{arg}:` but {name} has no such parameter")
        if cname in C:  # a {Placeholder} the component cannot fill renders as literal text in Dev Mode
            known = {pr[0] for pr in C[cname]["props"]} | set(C[cname]["axes"]) | {sl[0] if isinstance(sl, tuple) else sl for sl in C[cname]["slots"]}
            for ph in re.findall(r"\{(\w+)\}", tpl):
                if ph not in known:
                    errors.append(f"{cname}: template placeholder {{{ph}}} is not a prop, axis or slot of the component")
        for axis, opts in C[cname]["axes"].items():
            enum = f"{'Button' if cname == 'CustomButton' else cname}{axis}"
            em = re.search(rf"enum {enum}\s*\{{([^}}]*)\}}", src)
            if not em or "{" + axis + "}" not in tpl:
                continue  # design-only axis (e.g. ChipState), rendered as a comparison
            members = re.findall(r"^\s*(\w+)\s*[,;]?\s*$", re.sub(r"///.*|//.*", "", em.group(1)), re.M)
            want = {_lower_camel(o) for o in opts}
            if set(members) != want:
                errors.append(f"{cname}.{axis}: FigCraft {sorted(want)} vs Dart enum {enum} {sorted(members)}")
        checked += 1
    return checked, errors


def dryrun(path):
    try:
        with open(path) as f:
            transport = DryTransport(json.load(f))
    except (OSError, ValueError, KeyError, TypeError) as err:
        print(f"FAIL {path}: {err}")
        return 1
    with TemporaryDirectory() as tmp, patch.multiple(
        sys.modules[__name__], raw=transport, REG=os.path.join(tmp, "frames.json"),
        CREG=os.path.join(tmp, "components.json"), TOKENS=os.path.join(tmp, "tokens.json"),
    ):
        try:
            failed = main(["all"], dry_dir=tmp)
        except Exception as err:
            print(f"FAIL dryrun: {err}")
            failed = 1
    for problem, label in transport.problems.items():
        print(f"FAIL {problem} (first seen in {label})")
    print(f"dryrun: {len(transport.calls)} commands, {failed + len(transport.problems)} problem(s)")
    return int(bool(failed or transport.problems))


def main(a=None, dry_dir=None):
    if a is None:
        a = sys.argv[1:]
    if not a:
        print(__doc__)
        return
    global ONLINE
    ONLINE = a[0] not in ("check", "verify-components")
    if a[0] == "setup":
        def job(_scratch):
            setup()
            build_components()
            drop_lib()
        scratch_run(job)
    elif a[0] == "screen":
        spec = json.load(open(a[1]))
        load_lib()
        try:
            rid, n, _ = build_screen(spec)
        finally:
            drop_lib()
        print(f"{spec['name']}: frame {rid}, {n} commands")
        if "--png" in a:
            export_png(rid, os.path.abspath(a[a.index("--png") + 1]))
    elif a[0] == "check":  # offline: expand specs without FigCraft, report errors
        bad = 0
        all_paths = sorted(glob.glob(os.path.join(HERE, "specs", "*.json")))
        paths = a[1:] or all_paths
        specs = [json.load(open(path)) for path in paths]
        frame_names = {json.load(open(path))["name"] for path in all_paths}
        for path, spec in zip(paths, specs):
            try:
                assert spec.get("page") in PAGES, f"page must be one of {PAGES}"
                assert spec.get("modal") in (None, "sheet", "dialog"), "modal must be sheet or dialog"
                also = spec.get("also", [])
                assert isinstance(also, list) and all(isinstance(a_, str) and (a_.startswith("/") or re.fullmatch(r"lib/\S+\.dart:\d+", a_)) for a_ in also), \
                    'also must be a list of "lib/...dart:LINE" or "/route" strings'
                for link in spec_links(spec):
                    assert isinstance(link.get("from"), str) and link["from"], "link needs a source node name"
                    assert link.get("to") in frame_names, f"link target frame {link.get('to')!r} does not exist"
                e = Emit(screen_mode(spec))
                for n in spec.get("top", []) + spec.get("body", []) + spec.get("bottom", []):
                    emit(e, n, "root", "v")
                for o in spec.get("overlay", []):
                    emit(e, o["node"], "root", "v")
                print(f"ok   {os.path.basename(path)}: {len(e.cmds)} nodes")
            except Exception as err:
                bad += 1
                print(f"FAIL {os.path.basename(path)}: {err}")
        errors = check_component_dimensions()
        for error in errors:
            print("FAIL", error)
        sys.exit(1 if bad or errors else 0)
    elif a[0] == "verify-components":
        checked, errors = verify_components()
        for e in errors:
            print("FAIL", e)
        print(f"verify-components: {checked} linked widgets checked, {len(errors)} problem(s)")
        sys.exit(1 if errors else 0)
    elif a[0] == "dryrun":
        catalog = os.path.join(HERE, "fc_commands.json")
        sys.exit(dryrun(a[1] if len(a) > 1 else catalog))
    elif a[0] == "export-connect":
        print("connect file:", export_connect())
    elif a[0] == "matrix":
        keys_path = os.path.join(HERE, "..", "render_keys.txt")
        with open(keys_path) as f:
            keys = a[1:] or [line.strip() for line in f if line.strip()]
        matrix(keys)
        ex("file.save", {})
    elif a[0] == "parity":  # after capture.py: real screens beside frames, scores, code links
        rows = parity()
        got = [r for r in rows if r[0] is not None]
        print(f"parity: {len(got)} captured of {len(rows)} screens;",
              f"{sum(parity_note(r[2]) == 'parity pass' for r in got)} passing")
        ex("file.save", {})
    elif a[0] in ("pull", "drift"):  # FigCraft document -> tokens.json (pull) or just compare (drift)
        tok, notes = doc_tokens()
        diff = token_diff(TOK, tok)
        for line in notes + diff:
            print(line)
        if a[0] == "drift":
            print("drift:", len(diff), "difference(s)")
            sys.exit(1 if diff else 0)
        if diff:
            json.dump(tok, open(TOKENS_JSON, "w"), indent=2)
            sys.path.insert(0, os.path.dirname(TOKENS_JSON))
            import tokens as T
            T.gen()
        print("pull:", len(diff), "change(s) written" if diff else "nothing to pull")
    elif a[0] == "all":
        return scratch_run(lambda scratch: build_all(dry_dir, scratch))
    else:
        print(__doc__)


def build_all(dry_dir, scratch):
    setup()
    reg = build_components()
    build_foundations()
    build_docs(reg, dryrun=dry_dir is not None)
    build_icons_page()
    failed = []
    pending_links, frame_ids, named_nodes = [], {}, {}
    for path in sorted(glob.glob(os.path.join(HERE, "specs", "*.json"))):
        try:
            spec = json.load(open(path))
            rid, n, nodes = build_screen(spec)
            frame_ids[spec["name"]] = rid
            named_nodes[spec["name"]] = nodes
            pending_links.extend((spec["name"], link) for link in spec_links(spec))
            print(f"ok   {os.path.basename(path)}: {n} commands")
        except Exception as err:  # keep going; report at the end
            failed.append(path)
            print(f"FAIL {os.path.basename(path)}: {err}")
    for source_frame, link in pending_links:
        source_id = named_nodes[source_frame].get(link["from"])
        if not source_id or link["to"] not in frame_ids:
            failed.append(source_frame)
            print(f"FAIL {source_frame}: link {link['from']!r} → {link['to']!r} has a missing endpoint")
            continue
        apply_links([(source_id, link["to"])], frame_ids, {})
    drop_lib()
    if dry_dir is not None:
        matrix(["dryrun"])
    rows = parity(dryrun=dry_dir is not None)
    print("parity:", sum(r[0] is not None for r in rows), "captured of", len(rows))
    print("tokens bound:", STATS["on"], "off-scale values:", STATS["off"],
          sorted(STATS["off_values"].items(), key=lambda x: -x[1])[:12])
    connect_file = export_connect(os.path.join(scratch, "figcraft.connect.json"))
    print("connect file:", connect_file)
    # Not saved, not published: a scratch build must never replace the working file or the library.
    print("scratch document built and left unsaved; failed:", len(failed), failed)
    return len(failed)


if __name__ == "__main__":
    sys.exit(main() or 0)
