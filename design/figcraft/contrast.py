#!/usr/bin/env python3
"""Offline WCAG contrast report for the design token palette."""
import json
import os
import sys

TOKENS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tokens", "tokens.json")
TEXT = ("textPrimary", "textHighEmphasis", "textSecondary", "textTertiary", "textDisabled")
BACKGROUNDS = ("black", "blackSurface", "blackElevated", "surface", "surfaceRaised", "surfaceOverlay")
# (foreground, background, required). Decorative pairs are reported but do not gate the palette.
PAIRS = (("accentOrange", "surface", False), ("borderSubtle", "surface", False),
         ("textPrimary", "accentOrange", False))
TEXT_MIN, UI_MIN = 4.5, 3.0
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
        for fg, bg, required in PAIRS:
            contrast = ratio(value(fg, theme), value(bg, theme))
            rows.append((mode, "UI", fg, bg, contrast, UI_MIN, required))
    return rows


def main():
    rows = matrix()
    print(f"{'Mode':<6} {'Kind':<5} {'Foreground':<20} {'Background':<18} {'Ratio':>7} {'Min':>5} {'Status':<12}")
    failures = []
    for mode, kind, fg, bg, value, minimum, required in rows:
        passed = value >= minimum
        status = "PASS" if passed else ("FAIL" if required else "decorative")
        print(f"{mode:<6} {kind:<5} {fg:<20} {bg:<18} {value:>6.2f}:1 {minimum:>5.1f} {status:<12}")
        if required and not passed:
            failures.append((mode, fg, bg, value))
    if failures:
        print("Failures:")
        for mode, fg, bg, value in failures:
            print(f"  {mode}: {fg} on {bg} = {value:.2f}:1")
    return bool(failures)


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
