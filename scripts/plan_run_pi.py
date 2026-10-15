#!/usr/bin/env python3
"""Sequential pi-only plan runner (Studio ornith). Run from the audit-r3 worktree root:
  python3 scripts/plan_run_pi.py [--only=R01,R02] [--from=R10] [--dry-run]
Per task: pi edits (pi-run.sh retries up to 3x from verify output), runner re-verifies, full-suite gate,
one more pi attempt on gate failure, commit on success / rollback of lib+test on failure.
Trace: docs/plans/audit-r3/{ledger.jsonl,STATUS.md,logs/R##.log}. Zero Claude tokens."""
import json, os, shlex, subprocess, sys, time, fcntl
from pathlib import Path
WT = Path(__file__).resolve().parent.parent
PLAN = WT / "docs/plans/audit-r3"
PI = Path.home() / ".claude/skills/pi-delegate/scripts/pi-run.sh"
LEDGER, STATUS, LOGS = PLAN / "ledger.jsonl", PLAN / "STATUS.md", PLAN / "logs"
PRE = "set -o pipefail; "
MAX_CONSEC_FAIL = 3

def sh(cmd, timeout=3600, env=None):
    p = subprocess.run(["bash", "-c", cmd], cwd=WT, capture_output=True, text=True, timeout=timeout,
                       env={**os.environ, **(env or {})})
    return p.returncode, p.stdout + p.stderr

def q(s): return shlex.quote(s)

def verify_cmd(t):
    parts = []
    if t["tests"]:
        parts.append("flutter test " + " ".join(t["tests"]) + " 2>&1 | tail -n 30 | tee /dev/stderr | rg 'All tests passed' >/dev/null")
    libs = [f for f in t["files"] if f.startswith("lib/") and f.endswith(".dart")]
    if libs:
        parts.append("! (dart analyze " + " ".join(libs) + " 2>&1 | rg '^\\s*error -')")
    for f, rx in t["must_add"]:
        parts.append(f"git diff -U0 -- {f} | rg '^\\+' | rg -e {q(rx)} >/dev/null")
    for f, rx in t["must_remove"]:
        parts.append(f"git diff -U0 -- {f} | rg '^-' | rg -e {q(rx)} >/dev/null")
    for f, rx in t["must_contain"]:
        parts.append(f"rg -U -e {q(rx)} {f} >/dev/null")
    return PRE + " && ".join(parts) if parts else "true"

def rollback():
    sh("git checkout -- lib test && git clean -fdq lib test")

def ctx_files(t):
    fs = [str(PLAN.relative_to(WT) / "CONTEXT.md")] + t["files"] + t["tests"]
    seen, out = set(), []
    for f in fs:
        if f not in seen and (WT / f).exists(): seen.add(f); out.append(f)
    return out

def run_pi(prompt, t, iters):
    cmd = f'{q(str(PI))} {q(prompt)} ' + " ".join(q(f) for f in ctx_files(t))
    env = {"PI_VERIFY": verify_cmd(t), "PI_MAX_ITERS": str(iters), "PI_CHECKPOINT": "0", "PI_TIMEOUT": "1200"}
    return sh(cmd, timeout=iters * 1500 + 600, env=env)

def gate():
    rc, out = sh(PRE + "flutter test 2>&1 | tail -n 25", timeout=3600)
    return rc == 0, out[-1500:]

def read_ledger():
    return [json.loads(l) for l in LEDGER.read_text().splitlines()] if LEDGER.exists() else []

def write_status(tasks):
    last = {}
    for r in read_ledger(): last[r["id"]] = r
    rows = ["# audit-r3 status (auto-generated)", "", "| id | finding | title | status | attempts | secs | commit |", "|---|---|---|---|---|---|---|"]
    n_pass = 0
    for t in tasks:
        r = last.get(t["id"])
        st = r["verdict"] if r else "pending"
        n_pass += st == "pass"
        rows.append(f"| {t['id']} | {t['finding']} | {t['title']} | {st} | {r['attempts'] if r else ''} | {r['secs'] if r else ''} | {r.get('commit','') if r else ''} |")
    rows += ["", f"{n_pass}/{len(tasks)} passed. Logs: docs/plans/audit-r3/logs/<id>.log, ledger: ledger.jsonl", f"Updated {time.strftime('%Y-%m-%d %H:%M:%S')}"]
    STATUS.write_text("\n".join(rows) + "\n")

def main():
    lock = open(PLAN / ".lock", "w")
    try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError: sys.exit("another plan_run_pi is active")
    LOGS.mkdir(exist_ok=True)
    arg = lambda k: next((a.split("=", 1)[1] for a in sys.argv if a.startswith(k + "=")), None)
    only = arg("--only"); only = only.split(",") if only else None
    frm = arg("--from"); dry = "--dry-run" in sys.argv
    tasks = json.loads((PLAN / "tasks.json").read_text())["tasks"]
    sh("git update-index --skip-worktree analysis_options.yaml")
    done = {r["id"] for r in read_ledger() if r["verdict"] == "pass"}
    started = frm is None
    consec = 0
    write_status(tasks)
    for t in tasks:
        if t["id"] == frm: started = True
        if not started or (only and t["id"] not in only): continue
        if t["id"] in done: print(t["id"], "already passed"); continue
        if any(a not in done for a in t["after"]): print(t["id"], "skipped: dependency not passed", t["after"]); continue
        if dry: print(t["id"], t["finding"], t["title"]); continue
        t0 = time.time(); rollback()
        log = [f"# {t['id']} {t['title']} [{t['finding']}]", "## prompt", t["prompt"], "## verify", verify_cmd(t)]
        base = (t["prompt"] + f"\n\nEdit only: {', '.join(t['files'] + t['tests'])}. Read docs/plans/audit-r3/CONTEXT.md first. When finished print DONE.")
        attempts, ok, why = 0, False, ""
        for attempt in (1, 2):
            attempts = attempt
            prompt = base if attempt == 1 else base + "\n\nYour previous attempt did not pass. Failure output:\n" + why + "\nFix only what this output says; keep the rest of your change."
            rc, out = run_pi(prompt, t, 3 if attempt == 1 else 2)
            log += [f"## pi attempt {attempt} rc={rc} (tail)", out[-3500:]]
            changed = sh("git status --porcelain lib test")[1].strip()
            if not changed: why = "no files were changed"; continue
            vrc, vout = sh(verify_cmd(t), timeout=1800)
            log += [f"## verify rc={vrc}", vout[-1500:]]
            if vrc != 0: why = "verify failed:\n" + vout[-1200:]; continue
            gok, gout = gate()
            log += [f"## gate ok={gok}", gout]
            if not gok: why = "FULL SUITE FAILED:\n" + gout[-1200:]; continue
            ok = True; break
        secs = round(time.time() - t0)
        rec = dict(id=t["id"], finding=t["finding"], title=t["title"], verdict="pass" if ok else "fail", attempts=attempts, secs=secs,
                   why="" if ok else why[-400:], diff=sh("git diff --shortstat HEAD")[1].strip())
        (LOGS / f"{t['id']}.log").write_text("\n\n".join(log))
        if ok:
            done.add(t["id"]); consec = 0
        else:
            rollback(); consec += 1
        with LEDGER.open("a") as f: f.write(json.dumps(rec, ensure_ascii=False) + "\n")
        write_status(tasks)
        if ok:
            sh(f'git add lib test docs/plans/audit-r3 && git commit -qm {q("fix(audit-r3): " + t["id"] + " " + t["title"] + " [" + t["finding"] + "] via pi")}')
            rec["commit"] = sh("git rev-parse --short HEAD")[1].strip()
            lines = [json.dumps(r, ensure_ascii=False) for r in read_ledger()[:-1]] + [json.dumps(rec, ensure_ascii=False)]
            LEDGER.write_text("\n".join(lines) + "\n"); write_status(tasks)
        print(t["id"], rec["verdict"], f"{secs}s", rec["why"][:120].replace("\n", " "))
        if consec >= MAX_CONSEC_FAIL: print("stopping: 3 consecutive failures"); break
    if not dry and not only:
        rc, out = sh(PRE + "flutter test 2>&1 | tail -n 15; dart analyze lib 2>&1 | rg -c '^\\s*error -' || true", timeout=3600)
        (PLAN / "FINAL.txt").write_text(f"exit={rc}\n{out}")
        print("final gate exit", rc)
    sh("git add docs/plans/audit-r3 && git commit -qm 'docs(audit-r3): status and ledger' || true")

if __name__ == "__main__": main()
