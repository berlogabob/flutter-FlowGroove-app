#!/usr/bin/env python3
"""For every task that failed on both executors, append a codex repair task <id>-r that may also edit the
failing test files named in the ledger. Run from repo root after a runner pass; then rerun plan_run.py."""
import json, re
from pathlib import Path
P = Path("docs/plans/audit-2026-11-13"); plan = json.loads((P / "tasks.json").read_text()); tasks = plan["tasks"]
led = {}
for l in (P / "ledger.jsonl").read_text().splitlines():
    r = json.loads(l); led.setdefault(r["id"], []).append(r)
ids = {t["id"] for t in tasks}; n = 0
why_ok = lambda rs: True
for t in list(tasks):
    rs = led.get(t["id"], [])
    if not rs or any(r["verdict"] == "pass" for r in rs) or t["id"].endswith("-r2") or t.get("skip"): continue
    rid = t["id"] + ("2" if t["id"].endswith("-r") else "-r")
    if rid in ids: continue
    if not why_ok(rs): pass
    tail = " ".join(r["verify_tail"] for r in rs)
    tests = sorted(set(re.findall(r"flutter_repsync_a1113/(test/\S+?_test\.dart)", tail)))
    why = rs[-1]["verify_tail"][-600:].replace("\n", " ")
    tasks.append(dict(id=rid, finding=t["finding"], executor="codex", title="repair: " + t["title"], files=sorted(set(t["files"][1:] + tests), key=str) and [t["files"][0]] + sorted(set(t["files"][1:] + tests)) or t["files"],
        prompt=t["prompt"] + f" CONTEXT: a previous attempt at this exact task was rolled back. Failure: {why} "
               "Make the intended change AND make the whole test suite pass. If an existing test asserts the old UI, update only those assertions "
               "to the new intended behaviour; never delete tests or weaken unrelated assertions. Run the named test files with flutter test before finishing.",
        verify=f"! git diff --quiet HEAD -- {t['files'][0]} && dart analyze {t['files'][0]}" + "".join(f" && flutter test {x}" for x in sorted(set(tests + [f for f in t["files"][1:] if f.startswith("test/")]))), after=t["after"], status="pending", timeout=1500)); n += 1
# tasks that depended on a failed task now depend on its repair
for t in tasks:
    t["after"] = [a + "-r" if a + "-r" in {x["id"] for x in tasks} and not any(r["verdict"] == "pass" for r in led.get(a, [])) else a for a in t["after"]]
for t in tasks:  # originals superseded by a repair task are not retried
    if t["id"] + "-r" in {x["id"] for x in tasks} or (t["id"].endswith("-r") and t["id"] + "2" in {x["id"] for x in tasks}): t["skip"] = "superseded by repair task"
(P / "tasks.json").write_text(json.dumps(plan, ensure_ascii=False, indent=1)); print("repair tasks added:", n)
