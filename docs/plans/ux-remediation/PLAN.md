# UX audit remediation — plan (2026-10-14)
Source: audit/2026-10-13-2353/report.md (26 findings). Goal: close sev-3 and the mechanical sev-2/1 findings with zero Claude tokens in the loop.

Roles (as always): pi = Studio ornith-1.5:35b via pi-delegate (single-file mechanical edits); codex = default OpenAI cloud model, `codex exec --full-auto` (judgment / multi-file, and automatic fallback when pi fails). Never point Codex at Studio.
Isolation: all work in git worktree ../flutter_repsync_ux on branch fix/ux-audit-2026-10-14 (main tree has user's uncommitted edits). Sequential, one task at a time.

Run: `python3 scripts/plan_run.py` (resume-safe; `--only=T01,T02`, `--dry-run`).
Per task: executor edits -> runner verifies (grep assertion + dart analyze error-level + targeted tests, pipefail) -> pass: commit `fix(ux): Txx ... [finding] via executor`; fail: rollback, retry once with codex; still failing: stays pending in ledger as fail. End: full `flutter test` -> FINAL.txt.
Tasks: tasks.json (19: 12 pi-first, 7 codex). Trace: finding id -> task -> commit -> ledger.jsonl line.

Measures (read from ledger.jsonl): tasks passed / 19; first-attempt pass rate per executor; pi->codex fallbacks; secs and diff lines per task; full-suite exit code; Claude tokens in loop = 0.
Acceptance: all tasks pass or are listed as fail with reason; FINAL.txt exit=0; no analyzer errors vs baseline 0.

Out of scope (human decision or prod data): Rehearsals-in-Tools IA move, seeding demo lyrics/chords (prod Firestore), orange-accent audit beyond T15, release-build load-time re-measure, re-audit on device (run /app-audit after merge), personal-events coverage on a real account.
Human step after run: review `git log fix/ux-audit-2026-10-14`, merge to second01, install on P30, re-run /app-audit.
