#!/usr/bin/env python3
"""adb flow suite (Maestro cannot run on EMUI). Run from repo root: python3 audit/<run>/flows.py [flow names]"""
import sys, re, json, time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent)); import cap
R = cap.RUN; T = "ZZAuditTest"
def labels(): return [n for n in cap.nodes() if n["label"]]
def find(rx, ns=None):
    for n in (ns or labels()):
        if re.search(rx, n["label"], re.I): return n
def tap(rx, wait=1.5):
    n = find(rx)
    if not n: raise RuntimeError(f"no element /{rx}/")
    cap.tap(*cap.center(n)); time.sleep(wait)
def expect(rx):
    if not find(rx): raise RuntimeError(f"expected /{rx}/ not on screen")
def shot(name): cap.cap("flow_" + name)
def back(): cap.adb("shell", "input", "keyevent", "KEYCODE_BACK"); time.sleep(1.5)
def net(on):
    for s in ("wifi", "data"): cap.adb("shell", "svc", s, "enable" if on else "disable")
    time.sleep(6 if on else 3)

def cold_start():
    cap.adb("shell", "am", "force-stop", "com.flowgroove.app"); t = time.time()
    cap.adb("shell", "monkey", "-p", "com.flowgroove.app", "-c", "android.intent.category.LAUNCHER", "1")
    while time.time() - t < 30:
        if find("Quick Actions"): shot("cold_home"); return {"time_to_home_s": round(time.time() - t, 1)}
    raise RuntimeError("Home not reached in 30s")
def song_crud():
    cap.reset(); time.sleep(4); tap("^Add song"); shot("song_form")
    cap.tap(540, 387); cap.adb("shell", "input", "text", T); back(); shot("song_title_typed")
    tap("^Save Song", 4); shot("song_saved")
    cap.reset(); time.sleep(4); tap("^Songs$", 3)
    for _ in range(12):
        if find(T): break
        cap.adb("shell", "input", "swipe", "540", "1900", "540", "500", "300"); time.sleep(1.2)
    expect(T); shot("song_in_list"); tap(T, 3); shot("song_detail")
    tap("^Edit", 3); shot("song_edit")
    # delete is only reachable by swipe-left on the list row (no menu entry)
    cap.reset(); time.sleep(4); tap("^Songs$", 3)
    for _ in range(12):
        if find(T): break
        cap.adb("shell", "input", "swipe", "540", "1900", "540", "500", "300"); time.sleep(1.2)
    y = str(cap.center(find(T))[1]); cap.adb("shell", "input", "swipe", "900", y, "200", y, "300"); time.sleep(1.5)
    shot("song_delete_confirm"); tap("^Delete$", 4); shot("song_deleted")
    cap.reset(); time.sleep(4); tap("^Songs$", 3)
    for _ in range(12):
        if find(T): raise RuntimeError("song still listed after delete")
        cap.adb("shell", "input", "swipe", "540", "1900", "540", "500", "300"); time.sleep(1)
def settings_toggle():
    cap.reset(); time.sleep(4); tap("^More$"); tap("^Settings", 3); shot("settings_before")
    tap("^Haptics"); shot("settings_toggled"); tap("^Haptics"); shot("settings_restored"); back(); 
def metronome():
    cap.reset(); time.sleep(4); tap("^Metronome", 3); shot("metronome_idle")
    n = find("^(Start|Play)")
    if not n: raise RuntimeError("no Start/Play control")
    cap.tap(*cap.center(n)); time.sleep(3); shot("metronome_running"); expect("^(Stop|Pause)"); tap("^(Stop|Pause)"); shot("metronome_stopped")
def offline_error():
    cap.reset(); time.sleep(4); net(False)
    try:
        tap("^Add song"); cap.tap(400, 195); cap.adb("shell", "input", "text", "nirvana"); time.sleep(8); shot("offline_search")
        cap.reset(); time.sleep(5); shot("offline_home"); tap("^Songs$", 3); shot("offline_songs")
    finally: net(True)
    cap.reset(); time.sleep(6); expect("Quick Actions"); shot("online_recovered")

FLOWS = [cold_start, song_crud, settings_toggle, metronome, offline_error]
want = sys.argv[1:]; res = []
for f in FLOWS:
    if want and f.__name__ not in want: continue
    t = time.time(); r = dict(name=f.__name__, passed=True, errors=[])
    try: r.update(f() or {})
    except Exception as e:
        r["passed"] = False; r["errors"] = [str(e)]
        try: shot(f.__name__ + "_FAIL")
        except Exception: pass
    r["duration_s"] = round(time.time() - t, 1); res.append(r); print(r, flush=True)
if not want: json.dump(res, open(f"{R}/flows-results.json", "w"), indent=1)
