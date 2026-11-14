#!/usr/bin/env python3
"""Progress + ETA from tasks.json and ledger.jsonl. No LLM. Run: python3 docs/plans/audit-2026-11-13/status.py"""
import json, subprocess, time, datetime
from pathlib import Path
P = Path(__file__).parent; tasks = json.loads((P / "tasks.json").read_text())["tasks"]
led = [json.loads(l) for l in (P / "ledger.jsonl").read_text().splitlines()]
ids = {t["id"] for t in tasks}; ok = {r["id"] for r in led if r["verdict"] == "pass"} & ids
tried = {r["id"] for r in led} & ids; failed = sorted(tried - ok); left = len(tasks) - len(tried)
cur = [r for r in led if r["id"] in ids][3:]  # skip the 3 config-only warmup records
per = sum(r["secs"] for r in cur) / max(1, len({r["id"] for r in cur})) + 5
by = {}
for r in led:
    if r["verdict"] == "pass": by[r["executor"]] = by.get(r["executor"], 0) + 1
run = subprocess.run(["pgrep", "-f", "plan_run.py"], capture_output=True).returncode == 0
eta = datetime.datetime.now() + datetime.timedelta(seconds=left * per)
print(f"runner: {'RUNNING' if run else 'stopped'} | tasks {len(tried)}/{len(tasks)} done: {len(ok)} pass, {len(failed)} fail, {left} left")
print(f"passes by executor: {by} | avg {per/60:.1f} min/task | ETA {eta:%H:%M} ({left*per/3600:.1f} h)")
if failed: print("failed:", ", ".join(failed))
