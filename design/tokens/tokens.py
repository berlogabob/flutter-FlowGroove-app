"""FlowGroove design tokens: one JSON file, synced both ways.

  tokens.json  ->  lib/theme/mono_pulse_tokens.g.dart   (gen; a `part` of mono_pulse_theme.dart)
  tokens.json <->  FigCraft variables + text styles     (design/figcraft/build.py: all | pull | drift)

  python3 design/tokens/tokens.py gen        # tokens.json -> generated Dart (after editing tokens.json)
  python3 design/tokens/tokens.py check      # offline: generated Dart is up to date (CI / test gate)
  python3 design/figcraft/build.py pull      # open FigCraft document -> tokens.json -> generated Dart
  python3 design/figcraft/build.py drift     # open FigCraft document vs tokens.json, exit 1 on difference
  python3 design/figcraft/build.py all       # tokens.json -> a fresh FigCraft document (and every screen)

  bootstrap: reads the hand-written theme from before the token split (git show 235db715:lib/theme/
  mono_pulse_theme.dart). Kept as the regression check that tokens.json still equals that theme.
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
TOKENS = os.path.join(HERE, "tokens.json")
THEME = os.path.join(REPO, "lib", "theme", "mono_pulse_theme.dart")
GEN = os.path.join(REPO, "lib", "theme", "mono_pulse_tokens.g.dart")

WEIGHTS = {"regular": 400, "medium": 500, "semibold": 600, "bold": 700}
FAMILY_KEYS = {"fontFamily": "body", "fontFamilyDisplay": "display", "fontFamilyControl": "control"}
NUMBER_GROUPS = [  # tokens.json key, Dart class, FigCraft collection
    ("spacing", "MonoPulseSpacing", "Spacing"),
    ("radius", "MonoPulseRadius", "Radius"),
    ("elevation", "MonoPulseElevation", "Elevation"),
    ("icon", "MonoPulseIcons", "Icon"),
    ("border", "MonoPulseBorder", "Border"),
]
PALETTE_COLL = "MonoPulse"


# ---------------------------------------------------------------- colour helpers
def dart_to_hex(argb):
    """0xAARRGGBB -> #RRGGBB or #RRGGBBAA."""
    a, rgb = argb[:2].upper(), argb[2:].upper()
    return f"#{rgb}" if a == "FF" else f"#{rgb}{a}"


def hex_to_dart(h):
    h = h.lstrip("#").upper()
    rgb, a = h[:6], (h[6:8] or "FF")
    return f"0x{a}{rgb}"


def class_body(src, name):
    m = re.search(rf"^(?:abstract final )?class {name}\b[^{{]*\{{", src, re.M)
    if not m:
        raise ValueError(f"class {name} not found")
    i, depth = m.end(), 1
    while depth:
        depth += {"{": 1, "}": -1}.get(src[i], 0)
        i += 1
    return src[m.end():i - 1]


def comment_after(body, pos):
    line_end = body.find("\n", pos)
    tail = body[pos:line_end]
    m = re.search(r"//\s*(.+)$", tail)
    return m.group(1).strip() if m else None


# ---------------------------------------------------------------- bootstrap from Dart
def bootstrap(theme=None, out=None):
    src = open(theme or THEME).read()
    tok = {"$schema": "flowgroove-tokens/1", "color": {}, "palette": {}, "font": {}, "fontWeight": {},
           "type": {}, "shadow": {}}
    # MonoPulseColors: literals, aliases, the list
    body = class_body(src, "MonoPulseColors")
    flat = re.sub(r"Color\(\s*(0x[0-9A-Fa-f]{8}),?\s*\)", r"Color(\1)", body)
    order = []
    for m in re.finditer(r"static const (Color|List<Color>) (\w+) = ([^;]+);", flat):
        kind, name, val = m.groups()
        note = comment_after(flat, m.end())
        if kind == "List<Color>":
            tok["colorLists"] = {name: re.findall(r"\b(\w+)\b", val.strip("[] \n"))}
            continue
        val = val.strip()
        lit = re.fullmatch(r"Color\((0x[0-9A-Fa-f]{8})\)", val)
        if lit:
            entry = {"value": dart_to_hex(lit.group(1)[2:])}
        elif val == "Colors.transparent":
            entry = {"value": "#00000000"}
        elif re.fullmatch(r"\w+", val):
            entry = {"alias": val}
        else:
            raise ValueError(f"MonoPulseColors.{name}: can't read {val!r}")
        if note:
            entry["note"] = note
        tok["color"][name] = entry
        order.append(name)
    # Palette: dark refs MonoPulseColors, light refs MonoPulseColors or literals
    pal = class_body(src, "MonoPulsePalette")
    for mode in ("dark", "light"):
        block = re.search(rf"static const {mode} = MonoPulsePalette\((.*?)\);", pal, re.S).group(1)
        for name, val in re.findall(r"(\w+): ([^,]+),", block):
            val = val.strip()
            lit = re.fullmatch(r"Color\((0x[0-9A-Fa-f]{8})\)", val)
            ref = re.fullmatch(r"MonoPulseColors\.(\w+)", val)
            hexv = dart_to_hex(lit.group(1)[2:]) if lit else resolve(tok["color"], ref.group(1))
            tok["palette"].setdefault(name, {})[mode] = hexv
    # Typography
    ty = class_body(src, "MonoPulseTypography")
    for k, v in re.findall(r"static const String (\w+) = '([^']+)';", ty):
        tok["font"][FAMILY_KEYS[k]] = v
    for k, w in re.findall(r"static const FontWeight (\w+) = FontWeight\.w(\d+);", ty):
        tok["fontWeight"][k] = int(w)
    for name, args in re.findall(r"static const TextStyle (\w+) = TextStyle\((.*?)\);", ty, re.S):
        a = dict(re.findall(r"(\w+): ([^,\n]+),", args))
        t = {"family": FAMILY_KEYS[a["fontFamily"].strip()], "size": num(a["fontSize"]),
             "weight": a["fontWeight"].strip()}
        if "height" in a:
            t["height"] = num(a["height"])
        if "letterSpacing" in a:
            t["letterSpacing"] = num(a["letterSpacing"])
        tok["type"][name] = t
    # Number classes
    for key, cls, _ in NUMBER_GROUPS:
        b = class_body(src, cls)
        tok[key] = {k: num(v) for k, v in re.findall(r"static const double (\w+) = ([\d.]+);", b)}
    tok["radius"].update({"button": 5, "fab": 6, "card": 7, "cardMaterial": 6})  # theme / AppCard literals, now named
    el = class_body(src, "MonoPulseElevation")
    for name, alpha, blur, ox, oy in re.findall(
            r"static BoxShadow (\w+) = BoxShadow\(\s*color: MonoPulseColors\.black\.withValues\(alpha: ([\d.]+)\),"
            r"\s*blurRadius: ([\d.]+),\s*offset: const Offset\(([\d.]+), ([\d.]+)\),\s*\);", el):
        tok["shadow"][name] = {"color": "black", "alpha": num(alpha), "blur": num(blur), "x": num(ox), "y": num(oy)}
    json.dump(tok, open(out or TOKENS, "w"), indent=2)
    print(f"wrote {out or TOKENS}: {len(tok['color'])} colours, {len(tok['palette'])} palette, "
          f"{len(tok['type'])} type styles")


def num(s):
    f = float(str(s).strip())
    return int(f) if f.is_integer() else f


def resolve(colors, name):
    e = colors[name]
    return e["value"] if "value" in e else resolve(colors, e["alias"])


# ---------------------------------------------------------------- Dart generation
def dnum(v):
    return f"{float(v):g}" if not float(v).is_integer() else str(int(v))


def gen_dart(tok):
    L = ["// GENERATED by design/tokens/tokens.py from design/tokens/tokens.json -- do not edit.",
         "// Change tokens in FigCraft (then `tokens.py pull`) or in tokens.json (then `tokens.py gen`).",
         "part of 'mono_pulse_theme.dart';", ""]
    L.append("class MonoPulseColors {")
    for name, e in tok["color"].items():
        val = f"Color({hex_to_dart(e['value'])})" if "value" in e else e["alias"]
        note = f" // {e['note']}" if e.get("note") else ""
        L.append(f"  static const Color {name} = {val};{note}")
    for name, items in tok.get("colorLists", {}).items():
        L.append(f"  static const List<Color> {name} = [{', '.join(items)}];")
    L += ["}", "", "/// Light-mode neutrals for [MonoPulsePalette.light] (dark ones are [MonoPulseColors]).",
          "abstract final class MonoPulseLight {"]
    for name, modes in tok["palette"].items():
        L.append(f"  static const Color {name} = Color({hex_to_dart(modes['light'])});")
    L += ["}", "", "class MonoPulseTypography {", "  MonoPulseTypography._();", ""]
    inv = {v: k for k, v in FAMILY_KEYS.items()}
    for k, fam in tok["font"].items():
        L.append(f"  static const String {inv[k]} = '{fam}';")
    for k, w in tok["fontWeight"].items():
        L.append(f"  static const FontWeight {k} = FontWeight.w{w};")
    for name, t in tok["type"].items():
        L.append(f"  static const TextStyle {name} = TextStyle(")
        L.append(f"    fontFamily: {inv[t['family']]},")
        L.append(f"    fontSize: {dnum(t['size'])},")
        L.append(f"    fontWeight: {t['weight']},")
        if "height" in t:
            L.append(f"    height: {dnum(t['height'])},")
        if "letterSpacing" in t:
            L.append(f"    letterSpacing: {dnum(t['letterSpacing'])},")
        L.append("  );")
    L += ["}", ""]
    for key, cls, _ in NUMBER_GROUPS:
        L.append(f"class {cls} {{")
        for k, v in tok[key].items():
            L.append(f"  static const double {k} = {dnum(v)};")
        if key == "elevation":
            for name, s in tok["shadow"].items():
                L += [f"  static BoxShadow {name} = BoxShadow(",
                      f"    color: MonoPulseColors.{s['color']}.withValues(alpha: {dnum(s['alpha'])}),",
                      f"    blurRadius: {dnum(s['blur'])},",
                      f"    offset: const Offset({dnum(s['x'])}, {dnum(s['y'])}),",
                      "  );"]
        L += ["}", ""]
    return "\n".join(L).rstrip() + "\n"


def fmt(code):
    import subprocess
    return subprocess.run(["dart", "format", "--output=show"], input=code, capture_output=True,
                          text=True, check=True).stdout


def gen():
    open(GEN, "w").write(fmt(gen_dart(json.load(open(TOKENS)))))
    print("wrote", GEN)


def check():
    want = fmt(gen_dart(json.load(open(TOKENS))))
    have = open(GEN).read() if os.path.exists(GEN) else ""
    if want != have:
        print("FAIL: lib/theme/mono_pulse_tokens.g.dart is stale; run `python3 design/tokens/tokens.py gen`")
        sys.exit(1)
    print("ok: generated Dart matches tokens.json")


if __name__ == "__main__":
    cmd, args = (sys.argv[1], sys.argv[2:]) if len(sys.argv) > 1 else ("", [])
    {"bootstrap": bootstrap, "gen": gen, "check": check}.get(cmd, lambda *_: print(__doc__))(*args)
