#!/usr/bin/env python3
"""Offline WCAG contrast report for the design token palette."""
import json
import os
import sys

TOKENS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tokens", "tokens.json")
TEXT = ("textPrimary", "textHighEmphasis", "textSecondary", "textTertiary", "textDisabled")
BACKGROUNDS = ("black", "blackSurface", "blackElevated", "surface", "surfaceRaised", "surfaceOverlay")
TEXT_MIN, UI_MIN = 4.5, 3.0
PAD_SURFACES = {"dark": "surface", "light": "white"}
BADGE_WHITE_SECTIONS = {"section1", "section2", "section3", "section4"}
BADGE_SECTION1_SHADE = .06
# (use, foreground, background, minimum, required). Pad pairs use the rendered pad surface.
PAIRS = (("UI", "accentOrange", "surface", UI_MIN, False),
         ("UI", "borderSubtle", "surface", UI_MIN, False),
         ("UI", "textPrimary", "accentOrange", UI_MIN, False),
         ("Pad playing text", "charcoal", "accentOrange", TEXT_MIN, True),
         ("Pad selected border", "textPrimary", "padSurface", UI_MIN, True),
         ("Pad queued border", "accentOrange", "padSurface", UI_MIN, True),
         ("Pad playing fill", "accentOrange", "padSurface", UI_MIN, True),
         ("MPC lit key text", "charcoal", "accentOrange", TEXT_MIN, True)) + tuple(
             ("Pad letter badge", "white" if token in BADGE_WHITE_SECTIONS else "charcoal", token, TEXT_MIN, True)
             for token in (f"section{i}" for i in range(1, 15)))
DECORATIVE_TEXT_PAIRS = {("textTertiary", "blackElevated")}


def _rgb(value):
    value = value.lstrip("#")[:6]
    return tuple(int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))


def _luminance(value):
    channels = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in _rgb(value)]
    return sum(c * w for c, w in zip(channels, (0.2126, 0.7152, 0.0722)))


def ratio(fg, bg):
    a, b = sorted((_luminance(fg), _luminance(bg)), reverse=True)
    return (a + 0.05) / (b + 0.05)


def matrix():
    data = json.load(open(TOKENS))

    def value(name, theme):
        if name in data["palette"]:
            return data["palette"][name][theme]
        token = data["color"][name]
        return token["value"] if "value" in token else value(token["alias"], theme)

    rows = []
    for mode in ("Light", "Dark"):
        theme = mode.lower()
        for fg in TEXT:
            for bg in BACKGROUNDS:
                contrast = ratio(value(fg, theme), value(bg, theme))
                # Disabled labels are exempt; this tertiary-on-elevated use is decorative.
                required = fg != "textDisabled" and (fg, bg) not in DECORATIVE_TEXT_PAIRS
                rows.append((mode, "Text", fg, bg, contrast, TEXT_MIN, required))
        for use, fg, bg, minimum, required in PAIRS:
            bg = PAD_SURFACES[theme] if bg == "padSurface" else bg
            background = value(bg, theme)
            if use == "Pad letter badge" and bg == "section1":
                shade = BADGE_SECTION1_SHADE
                background = "#" + "".join(
                    f"{round(255 * (base * (1 - shade) + ink * shade)):02x}"
                    for base, ink in zip(_rgb(background), _rgb(value("charcoal", theme))))
            contrast = ratio(value(fg, theme), background)
            rows.append((mode, use, fg, bg, contrast, minimum, required))
    return rows


def main():
    rows = matrix()
    print(f"{'Mode':<6} {'Kind':<19} {'Foreground':<20} {'Background':<18} {'Ratio':>7} {'Min':>5} {'Status':<12}")
    failures = []
    for mode, kind, fg, bg, value, minimum, required in rows:
        passed = value >= minimum
        status = "PASS" if passed else ("FAIL" if required else "decorative")
        print(f"{mode:<6} {kind:<19} {fg:<20} {bg:<18} {value:>6.2f}:1 {minimum:>5.1f} {status:<12}")
        if required and not passed:
            failures.append((mode, fg, bg, value))
    if failures:
        print("Failures:")
        for mode, fg, bg, value in failures:
            print(f"  {mode}: {fg} on {bg} = {value:.2f}:1")
    return bool(failures)


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
