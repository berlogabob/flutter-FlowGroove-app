#!/usr/bin/env python3
"""plan.py merge | trace   (run from repo root)
merge: validate gen/<ID>.json task arrays and append new ones to tasks.json.
trace: rebuild TRACE.md (problem -> tasks -> ledger verdict/executor -> commit) and sync PROBLEMS.md status."""
import json, re, subprocess, sys
from pathlib import Path
P = Path("docs/plans/audit-2026-11-13"); WT = Path("../flutter_repsync_a1113")
TJ = P / "tasks.json"; KEYS = {"id", "finding", "executor", "title", "files", "prompt", "verify", "after", "status"}
def load(): return json.loads(TJ.read_text()) if TJ.exists() else {"branch": "fix/audit-2026-11-13", "tasks": []}
def order(pid):
    f = load.__dict__.setdefault("o", ["M-02", "M-04", "F-001", "F-002", "F-003", "F-004", "F-005"])
    return (f.index(pid) if pid in f else 100, pid.startswith("M-"), pid)
def set_status(pid, st, only_from=None):
    L = (P / "PROBLEMS.md").read_text().split("\n")
    for i, l in enumerate(L):
        if l.startswith(f"| {pid} "):
            c = l.split(" | "); cur = c[-1].rstrip(" |")
            if only_from is None or cur in only_from: c[-1] = st + " |"; L[i] = " | ".join(c)
    (P / "PROBLEMS.md").write_text("\n".join(L))
def merge():
    plan = load(); have = {t["id"] for t in plan["tasks"]}; new = []
    for g in sorted((P / "gen").glob("*.json"), key=lambda g: order(g.stem)):
        pid = g.stem; t = g.read_text().strip()
        try: arr = json.loads(t[t.index("["):t.rindex("]") + 1])
        except Exception as e: print("BAD JSON", pid, e); continue
        if not arr: set_status(pid, "deferred (generator: needs decision or not reproducible from code)", {"open"}); print("EMPTY", pid); continue
        for x in arr:
            if x.get("id") in have: continue
            bad = KEYS - set(x) or not 1 <= len(x["files"]) <= 3 or x["finding"] != pid
            if bad: print("INVALID", x.get("id"), bad); continue
            x["after"] = [a for a in x["after"] if a != x["id"]]; x["timeout"] = 900; new.append(x); have.add(x["id"])
        set_status(pid, "tasked", {"open"})
    plan["tasks"] += new; TJ.write_text(json.dumps(plan, ensure_ascii=False, indent=1)); print("added", len(new), "total", len(plan["tasks"]))
def trace():
    tasks = load()["tasks"]; led = {}
    if (P / "ledger.jsonl").exists():
        for l in (P / "ledger.jsonl").read_text().splitlines():
            r = json.loads(l); led.setdefault(r["id"], []).append(r)
    log = subprocess.run(["git", "-C", str(WT), "log", "--format=%h %s", "second01..HEAD"], capture_output=True, text=True).stdout.splitlines()
    commit = {m.group(1): l.split()[0] for l in log if (m := re.search(r": (\S+) ", l))}
    L = ["# Trace — problem -> task -> executor/verdict -> commit", "", "| Problem | Task | File | Result | Commit |", "|---|---|---|---|---|"]; by = {}
    for t in tasks:
        rs = led.get(t["id"], []); ok = [r for r in rs if r["verdict"] == "pass"]
        res = f"pass via {ok[0]['executor']}" if ok else ("FAIL x%d: %s" % (len(rs), rs[-1]["verify_tail"][-80:].replace("\n", " ").replace("|", "/")) if rs else "pending")
        L.append(f"| {t['finding']} | {t['id']} {t['title']} | {t['files'][0]} | {res} | {commit.get(t['id'], '')} |"); d = by.setdefault(t["finding"], {}); k = t["id"].split("-r")[0]; d[k] = d.get(k, False) or bool(ok)
    for pid, v in by.items():
        if all(v.values()): set_status(pid, "fixed", {"open", "tasked"})
    (P / "TRACE.md").write_text("\n".join(L) + "\n")
    c = lambda s: sum(1 for l in (P / "PROBLEMS.md").read_text().split("\n") if l.rstrip(" |").endswith(s))
    print({s: c(s) for s in ("open", "tasked", "fixed", "verified")}, "failed tasks:", [t["id"] for t in tasks if led.get(t["id"]) and not any(r["verdict"] == "pass" for r in led[t["id"]])])
{"merge": merge, "trace": trace}[sys.argv[1]]()
