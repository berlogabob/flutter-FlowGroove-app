"""Screenshot the real app for every spec that has a `route`, from an Android device over adb.

  python3 capture.py                 # every routed spec
  python3 capture.py home songs_list # just these spec keys
  python3 capture.py --dry-run       # print the deep links, touch nothing
  python3 capture.py --signed-out    # only the Auth-page specs; sign out on the device first
                                     # (a signed-in session redirects /login and /register to Home)

Needs a DEBUG build installed (flutter run / flutter install --debug): only debug builds carry the
flowgroove-debug://app/<route> link (android/app/src/debug/AndroidManifest.xml). The app should be
signed in; it is launched once, then each route is opened as a deep link into the running app
(a cold-start deep link would race Firebase auth restore and land on /login).

Route placeholders ({band}, {song}, {setlist}, {rehearsal}, {invite}) come from design/real/ids.json,
ids of the signed-in account, e.g. {"band": "abc", "song": "def"}. Specs whose placeholders are
missing are skipped and listed.

Output: design/real/<key>.png scaled to 412 px wide, design/real/index.json with route, device,
time and theme per key. build.py parity reads both.
"""
import datetime, glob, json, os, re, shutil, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
REAL = os.path.join(HERE, "..", "real")
PKG = "com.flowgroove.app"
ADB = shutil.which("adb") or os.path.expanduser("~/Library/Android/sdk/platform-tools/adb")
W = 412
# Tab roots: a platform deep link to these shows Back instead of the tab bar (the app treats it as a push),
# so they are reached like a user does: fresh launch, then tap the tab. Index into the 5-slot bottom bar.
TABS = {"/main/home": 0, "/main/songs": 1, "/main/bands": 2, "/main/setlists": 3}
SETTLE = float(os.environ.get("CAPTURE_SETTLE", "3.5"))  # seconds after a deep link; raise on slow data loads


def adb(*args, out=False):
    r = subprocess.run([ADB, *SERIAL, *args], capture_output=True, check=True)
    return r.stdout if out else None


def devices():
    lines = subprocess.run([ADB, "devices"], capture_output=True, text=True).stdout.splitlines()[1:]
    return [l.split()[0] for l in lines if l.strip().endswith("device")]


def routed_specs(keys):
    out = []
    for path in sorted(glob.glob(os.path.join(HERE, "specs", "*.json"))):
        key = os.path.basename(path)[:-5]
        spec = json.load(open(path))
        if spec.get("route") and (not keys or key in keys):
            out.append((key, spec))
    return out


def fill(route, ids):
    missing = [p for p in re.findall(r"\{(\w+)\}", route) if p not in ids]
    return None if missing else re.sub(r"\{(\w+)\}", lambda m: ids[m.group(1)], route), missing


def main():
    global SERIAL
    args = sys.argv[1:]
    dry = "--dry-run" in args
    keys = [a for a in args if not a.startswith("--")]
    ids_path = os.path.join(REAL, "ids.json")
    ids = json.load(open(ids_path)) if os.path.exists(ids_path) else {}
    plan, skipped = [], []
    signed_out = "--signed-out" in args
    for key, spec in routed_specs(keys):
        if (spec.get("page") == "Auth") != signed_out:
            continue
        route, missing = fill(spec["route"], ids)
        (plan.append((key, route)) if route else skipped.append((key, missing)))
    for key, missing in skipped:
        print(f"skip {key}: needs {', '.join(missing)} in design/real/ids.json")
    if dry:
        for key, route in plan:
            print(f"{key:22} flowgroove-debug://app{route}")
        return
    devs = devices()
    if not devs:
        sys.exit("no adb device: connect the phone (USB debugging on) and retry")
    SERIAL = ["-s", os.environ.get("ANDROID_SERIAL", devs[0])]
    model = subprocess.run([ADB, *SERIAL, "shell", "getprop", "ro.product.model"], capture_output=True,
                           text=True).stdout.strip()
    night = subprocess.run([ADB, *SERIAL, "shell", "cmd", "uimode", "night"], capture_output=True,
                           text=True).stdout.strip()
    os.makedirs(REAL, exist_ok=True)
    index_path = os.path.join(REAL, "index.json")
    index = json.load(open(index_path)) if os.path.exists(index_path) else {}
    size = subprocess.run([ADB, *SERIAL, "shell", "wm", "size"], capture_output=True, text=True).stdout
    sw, sh = map(int, re.search(r"(\d+)x(\d+)", size.split("Override")[-1]).groups())

    def fresh():  # every screen starts from a clean stack: no leftover pushes, no open sheets
        adb("shell", "am", "force-stop", PKG)
        adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
        time.sleep(9)  # first frame + auth restore

    for key, route in plan:
        fresh()
        if route in TABS:
            if TABS[route]:
                adb("shell", "input", "tap", str(int((TABS[route] + 0.5) / 5 * sw)), str(int(sh * 0.972)))
        else:
            adb("shell", "am", "start", "-a", "android.intent.action.VIEW", "-p", PKG,
                "-d", f"'flowgroove-debug://app{route}'")
        time.sleep(SETTLE)
        raw = os.path.join(REAL, f".{key}.raw.png")
        with open(raw, "wb") as f:
            f.write(adb("exec-out", "screencap", "-p", out=True))
        dst = os.path.join(REAL, f"{key}.png")
        subprocess.run(["magick", raw, "-resize", f"{W}x", "-strip", dst], check=True)
        os.remove(raw)
        index[key] = {"route": route, "device": model, "night": night,
                      "captured": datetime.datetime.now().isoformat(timespec="seconds")}
        print(f"ok   {key:22} {route}")
        json.dump(index, open(index_path, "w"), indent=1)
    print(f"captured {len(plan)}, skipped {len(skipped)} -> {os.path.abspath(REAL)}")


SERIAL = []
if __name__ == "__main__":
    main()
