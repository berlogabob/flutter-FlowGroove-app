#!/usr/bin/env python3
"""Targeted device captures for findings the crawl did not cover + N-rows. Run from repo root with rundir set."""
import sys, time; sys.argv = ["x", "none"]; sys.path.insert(0, "audit/2026-11-13-1417")
import flows as f, cap
def home(): cap.reset(); time.sleep(5)
def swipe(): cap.adb("shell", "input", "swipe", "540", "1900", "540", "700", "400"); time.sleep(1.5)
def t_F001(): home(); f.tap("^This week", 4); f.tap("^Continue", 8); f.shot("v_F-001")
def t_F029_F022():
    home(); f.tap("^Songs$", 3); f.tap("^Basketcase", 4); f.shot("v_F-029"); f.tap("^Menu$"); f.tap("^Song editor", 4); f.shot("v_F-022")
def t_F026_F033():
    home(); f.tap("^Songs$", 3); f.tap("^Metronome for Back to Black", 5); f.shot("v_F-026_a"); swipe(); f.shot("v_F-026_b"); swipe(); f.shot("v_F-033")
def t_F027(): home(); f.tap("^Songs$", 3); f.tap("^Key / BPM", 3); f.shot("v_F-027_a"); swipe(); f.shot("v_F-027_b")
def t_F006():
    home(); f.net(False)
    try:
        f.tap("^Add song"); f.tap("^Search the web", 3); cap.adb("shell", "input", "text", "nirvana"); cap.adb("shell", "input", "keyevent", "KEYCODE_ENTER"); time.sleep(9); f.shot("v_F-006")
    finally: f.net(True)
def t_N006(): home(); f.tap("^Tuner", 4); f.tap("Guitar", 3); f.shot("v_N-006")
def t_N008(): home(); f.tap("^Tuner", 4); f.tap("^Tone", 3); f.shot("v_N-008_a"); n = f.find("^C$") or f.find("Select note"); n and (cap.tap(*cap.center(n)), time.sleep(2)); f.shot("v_N-008_b")
def t_N007_N009_N010():
    home(); f.tap("^Add song", 3); f.shot("v_N-009"); f.tap("^Metronome Settings", 3); f.shot("v_N-007_a"); swipe(); f.shot("v_N-007_b")
    home(); f.tap("^Add song", 3); f.tap("^Tags", 3); f.shot("v_N-010_a"); swipe(); f.shot("v_N-010_b")
def t_N011(): home(); f.tap("^Bands$", 4); f.shot("v_N-011_a"); swipe(); f.shot("v_N-011_b")
for name, fn in list(globals().items()):
    if name.startswith("t_"):
        try: fn(); print("ok", name, flush=True)
        except Exception as e: print("FAIL", name, e, flush=True)
