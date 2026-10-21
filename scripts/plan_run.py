#!/usr/bin/env python3
"""Unattended plan runner: pi (Studio ornith 35b) and codex execute tiny tasks; this script verifies,
commits, ledgers and rolls back. Zero Claude tokens. Usage: plan_run.py [--only T01,T02] [--dry-run]
Plan: docs/plans/ux-remediation/{PLAN.md,tasks.json}; ledger: ledger.jsonl next to it."""
import json, os, subprocess, sys, time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PLAN = REPO / os.environ.get("PLAN_DIR", "docs/plans/ux-remediation")
WT = REPO.parent / os.environ.get("PLAN_WT", "flutter_repsync_ux")
PFX = os.environ.get("PLAN_PREFIX", "fix(ux)")  # git worktree, isolates the user's dirty main tree
PI = Path.home() / ".claude/skills/pi-delegate/scripts/pi-run.sh"
LEDGER = PLAN / "ledger.jsonl"
PRE = "set -o pipefail; "

def sh(cmd, cwd=WT, timeout=1800, env=None):
    p = subprocess.run(["bash", "-c", cmd], cwd=cwd, capture_output=True, text=True, timeout=timeout,
                       env={**os.environ, **(env or {})})
    return p.returncode, (p.stdout + p.stderr)

def verify(task):
    # analyzer: fail only on error-level issues (baseline has 0 errors, ~238 infos)
    v = task["verify"].replace("dart analyze", "dartan")
    pre = PRE + "dartan(){ ! dart analyze \"$@\" 2>&1 | rg -q '^\\s*error -'; }; "
    rc, out = sh(pre + v, timeout=1500)
    return rc == 0, out[-2500:]

def run_exec(ex, task):
    files = " ".join(task["files"])
    if ex == "pi":
        # pi-run.sh treats file args as files to READ and aborts on missing ones (new files)
        files = " ".join(f for f in task["files"] if (WT / f).is_file())
        env = {"PI_VERIFY": "", "PI_MAX_ITERS": "1", "PI_CHECKPOINT": "0", "PI_TIMEOUT": str(task.get("timeout", 900))}
        cmd = f'"{PI}" {json.dumps(task["prompt"])} {files}'
        return sh(cmd, env=env, timeout=task.get("timeout", 900) + 60)
    cmd = f'codex exec -C "{WT}" {json.dumps(task["prompt"] + " Allowed files: " + (files or "any under lib/"))} </dev/null'
    return sh(cmd, timeout=1500)

def diffstat():
    return sh("git diff --shortstat HEAD")[1].strip()

def rollback():
    sh("git checkout -- . && git clean -fdq")

def main():
    import fcntl
    lock = open(PLAN / '.lock', 'w')
    try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError: sys.exit('another plan_run is active')
    only = next((a.split("=")[1].split(",") for a in sys.argv if a.startswith("--only=")), None)
    dry = "--dry-run" in sys.argv
    sh("git update-index --skip-worktree analysis_options.yaml")  # dart analyze rewrites it
    plan = json.loads((PLAN / "tasks.json").read_text())
    done = {json.loads(l)["id"] for l in LEDGER.read_text().splitlines() if '"verdict": "pass"' in l} if LEDGER.exists() else set()
    for t in plan["tasks"]:
        if only and t["id"] not in only: continue
        if t.get("skip"): print(t["id"], "skipped:", t["skip"]); continue
        if t["id"] in done: print(t["id"], "already passed"); continue
        if any(a not in done for a in t["after"]):
            print(t["id"], "skipped: dependency not passed", t["after"]); continue
        if dry: print(t["id"], t["executor"], t["title"]); continue
        order = [t["executor"]] + (["codex"] if t["executor"] == "pi" else [])
        for n, ex in enumerate(order, 1):
            t0 = time.time(); rollback()
            rc, log = run_exec(ex, t)
            ok, vout = verify(t) if sh("git status --porcelain")[1].strip() else (False, "no changes made")
            stat = diffstat()
            if ok and t.get("suite", True):  # regression gate: whole suite must stay green (caught T11 breaking 39 tests)
                rc2, o2 = sh(PRE + "flutter test 2>&1 | tail -8", timeout=3000)
                if rc2 != 0: ok, vout = False, 'FULL SUITE FAILED: ' + o2[-400:]
            rec = dict(id=t["id"], finding=t["finding"], executor=ex, attempt=n, secs=round(time.time() - t0),
                       exec_rc=rc, verdict="pass" if ok else "fail", diff=stat, verify_tail=vout if not ok else "")
            if ok:
                sh(f'git add -A && git commit -qm "{PFX}: {t["id"]} {t["title"]} [{t["finding"]}] via {ex}"')
                done.add(t["id"])
            else:
                rollback()
            with LEDGER.open("a") as f: f.write(json.dumps(rec, ensure_ascii=False) + "\n")
            print(rec["id"], ex, rec["verdict"], stat)
            if ok: break
    # final gate: full analyzer + test suite, honest exit code
    if not dry and not only:
        rc, out = sh(PRE + "flutter test 2>&1 | tail -15", timeout=3000)
        (PLAN / "FINAL.txt").write_text(f"flutter test exit={rc}\n{out}")
        print("final suite exit", rc)

if __name__ == "__main__":
    main()
