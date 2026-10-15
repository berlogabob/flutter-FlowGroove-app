#!/usr/bin/env python3
"""adb capture helpers: cap(name) -> screenshot + hierarchy json; nodes(); tap(x,y)."""
import subprocess, re, json, sys, os, time, html
ADB=os.path.expanduser("~/Library/Android/sdk/platform-tools/adb"); S="XPH0219904001750"
RUN=open("/private/tmp/claude-501/sp/rundir").read().strip()
BASE="/Users/berloga/Documents/GitHub/flutter_repsync_app/"
def adb(*a, **k): return subprocess.run([ADB,"-s",S,*a],capture_output=True,**k)
def dump():
    for _ in range(4):
        adb("shell","rm","-f","/sdcard/u.xml")
        r=adb("shell","uiautomator","dump","/sdcard/u.xml",text=True)
        x=adb("shell","cat","/sdcard/u.xml",text=True).stdout
        if "<hierarchy" in x: return x
        time.sleep(1.5)
    return ""
def nodes(x=None):
    x=x or dump(); out=[]
    for m in re.finditer(r'<node [^>]*>',x):
        t=m.group(0)
        g=lambda k:(re.search(k+r'="([^"]*)"',t) or [None,""])[1]
        b=re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',t)
        if not b: continue
        x1,y1,x2,y2=map(int,b.groups())
        out.append(dict(label=html.unescape(g("content-desc") or g("text")).replace("\n"," | "),
            clickable=g("clickable")=="true",bounds=[x1,y1,x2,y2],cls=g("class")))
    return out
def shot(path): open(path,"wb").write(adb("exec-out","screencap","-p").stdout)
def cap(name):
    x=dump(); ns=nodes(x)
    shot(BASE+RUN+f"/screens/{name}.png")
    json.dump([dict(accessibilityText=n["label"],bounds=f"[{n['bounds'][0]},{n['bounds'][1]}][{n['bounds'][2]},{n['bounds'][3]}]",clickable=n["clickable"]) for n in ns],open(BASE+RUN+f"/hierarchy/{name}.json","w"),ensure_ascii=False)
    return ns
def tap(x,y): adb("shell","input","tap",str(x),str(y)); time.sleep(1.8)
def center(n): b=n["bounds"]; return (b[0]+b[2])//2,(b[1]+b[3])//2
def reset():
    adb("shell","am","force-stop","com.flowgroove.app")
    adb("shell","monkey","-p","com.flowgroove.app","-c","android.intent.category.LAUNCHER","1"); time.sleep(8)
if __name__=="__main__":
    ns=cap(sys.argv[1]); [print(n["clickable"],n["label"],n["bounds"]) for n in ns if n["label"]]
