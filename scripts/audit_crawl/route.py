import cap, time, sys, json
def run(name, taps, fresh=True, wait=2.2):
    if fresh: cap.reset()
    for t in taps:
        if t=="demo": cap.tap(540,1807); time.sleep(5); continue
        if isinstance(t,(int,float)): time.sleep(t); continue
        if t=="back": cap.adb("shell","input","keyevent","KEYCODE_BACK"); time.sleep(1.5); continue
        if t[0]=="swipe": cap.adb("shell","input","swipe",*map(str,t[1:])); time.sleep(1.2); continue
        cap.tap(*t)
    time.sleep(wait); cap.shot(cap.BASE+cap.RUN+f"/screens/{name}.png"); print("captured",name)
NAV={"home":(126,2260),"songs":(333,2260),"bands":(539,2260),"setlists":(746,2260),"menu":(952,2260)}
if __name__=="__main__":
    run("03_home_demo",["demo",3],fresh=False)
