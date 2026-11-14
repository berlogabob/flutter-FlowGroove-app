#!/usr/bin/env python3
"""Label-driven BFS crawl (depth 2) over adb. Waits for the APK build, installs, crawls.
Run from repo root: python3 audit/<run>/crawl.py"""
import sys, os, re, json, time, hashlib, subprocess
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent)); import cap
R = cap.RUN; ST = f"{R}/migration/status.txt"
APK = "build/app/outputs/flutter-apk/app-release.apk"
SKIP = re.compile(r"delete|remove|sign ?out|log ?out|leave|share|invite|telegram|privacy|terms|rate |website|upgrade|purchase|export|import|allow|deny|while using the app|only this time", re.I)
MAXV, MAXKIDS = 170, 12

if os.environ.get("INSTALL"):  # unset = audit the build already on the device
    while "buildapk" not in "".join(l for l in open(ST) if l.startswith("exit=")): time.sleep(15)
    if "exit=0 buildapk" not in open(ST).read(): sys.exit("BUILD FAILED - see migration/buildapk.txt")
    r = cap.adb("install", "-r", APK, text=True); print("install:", r.stdout.strip()[-200:], r.stderr.strip()[-300:], flush=True)
    if "Success" not in r.stdout: sys.exit("INSTALL FAILED")

def sig(ns): return hashlib.md5("|".join(sorted(re.sub(r"\d+", "#", n["label"]) for n in ns if n["label"])).encode()).hexdigest()[:10]
def slug(s): return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")[:28] or "x"
def replay(path):
    cap.reset(); time.sleep(4)
    for st in path:
        if st[0] == "swipe": cap.adb("shell", "input", "swipe", "540", "1900", "540", "700", "400"); time.sleep(1.5)
        else: cap.tap(st[1], st[2]); time.sleep(1.2)
def kids(ns, depth):
    out = []
    for n in ns:
        l = n["label"]; b = n["bounds"]
        nav = depth == 0 and b[1] >= 2150 and l
        if not l or SKIP.search(l) or not (n["clickable"] or nav): continue
        if depth > 0 and b[1] >= 2150: continue  # bottom nav already covered from Home
        out.append((l.split(" | ")[0][:40], *cap.center(n)))
    return out if depth == 0 else out[:MAXKIDS]

seen, index, queue, visits = set(), [], [[]], 0
while queue and visits < MAXV:
    path = queue.pop(0); visits += 1
    try:
        replay(path)
        if "com.flowgroove.app" not in cap.adb("shell", "dumpsys window | grep mCurrentFocus", text=True).stdout:
            cap.reset()
            if "com.flowgroove.app" not in cap.adb("shell", "dumpsys window | grep mCurrentFocus", text=True).stdout: continue
        ns = cap.nodes(); s = sig(ns)
        if s in seen or not ns: continue
        seen.add(s)
        name = f"{len(index)+1:02d}_" + ("home" if not path else "__".join(slug(p[0]) for p in path))
        cap.cap(name); index.append(dict(name=name, path=[p[0] for p in path], nodes=len(ns)))
        print("captured", name, len(ns), "queue", len(queue), flush=True)
        depth = len([p for p in path if p[0] != "swipe"])
        if depth < 2: queue += [path + [k] for k in kids(ns, depth)]
        if not any(p[0] == "swipe" for p in path): queue.append(path + [("swipe",)])
    except Exception as e: print("FAIL", path, e, flush=True)
    json.dump(index, open(f"{R}/screens.json", "w"), ensure_ascii=False, indent=1)
print("CRAWLDONE", len(index), "screens", visits, "visits")
