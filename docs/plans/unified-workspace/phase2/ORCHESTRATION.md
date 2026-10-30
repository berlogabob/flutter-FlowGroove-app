# Phase 2 orchestration ledger

Hermes decomposed the work, drove the P30, fetched sources, verified every worker output and wrote the synthesis. Workers got one small deliverable each. Ornith ran serially on LAN Studio, and cloud workers used cheap tiers. Runners: `~/.hermes/cache/scratch/fg_p2_local.py`, `fg_p2_cloud.py` (Ornith quote check has a built-in assert self-test).

| ID | Model (requested → runtime) | Task | Result | Verification by Hermes |
|---|---|---|---|---|
| L05 | Ornith 1.5 35b → same | Moises pattern table from sources | 11 rows, 72 s | quotes 11/11 literal ✓. O03: 1 WRONG (speed = metronome speed), 1 WRONG (perform), 1 OVERREACH (feedback); dropped/marked |
| L06 | Ornith → same | Melodics | 9 rows, 47 s | quotes 9/9 ✓. O03: 2 WRONG (import, create), 3 OVERREACH; reworded |
| L07 | Ornith → same | Yousician | 11 rows, 51 s | quotes 11/11 ✓. O03: 3 OVERREACH (perform, create, fretboard as app feature); marked |
| L08 | Ornith → same | Drumeo (after C02 sources) | 11 rows, 60 s | quotes 11/11 ✓. Hermes: count-in row WRONG (metronome ≠ count-in); dropped |
| L09 | Ornith → same | Critique of proposal vs new findings (14.7 k-char prompt) | **FAILED: `finish_reason=length`, 8192 tokens all reasoning, empty content**, 119 s | not used; replaced by L09b (narrower new task, not a retry of the same prompt) |
| L09b | Ornith → same, max_tokens 16384 | 4 slice changes, ≤150 words, 4.3 k-char prompt | returned in 16 s | all 4 match Hermes' draft. Corrected "existing fields": section/track need new optional session fields |
| C02 #1 | Claude Haiku | Drumeo first-party sources (web) | **FAILED infra**: `timeout` binary missing on macOS (orchestrator bug) | rerun with python timeout |
| C02 | haiku → `claude-haiku-5-5` | same | 4 sources, 62 s, $0.057 | every excerpt sentence re-fetched with curl: 18/18 literal ✓. Honest GAPS line kept |
| O03 | `gpt-6-luna` (runtime header not retained: stderr tail-truncated) | semantic check of L05–L07 rows | 11 non-OK / 18 OK, 15 s | spot-checked against sources; adopted |
| C03 | haiku → `claude-haiku-5-5` | verify P30-FLOW CODE claims D13/D14/D16/D21 | 3 TRUE, 1 PARTLY, 39 s, $0.014 | D16 corrected (band songs also get an assignee field) |

Ornith's role: 6 of 10 attempts, all extraction/critique. It was the most used and handled extraction reliably with literal quotes, but it over-reads Stage labels. A cheap semantic checker (Luna) caught those. Failure mode seen: long prompt + reasoning model → budget spent on reasoning (`length`, empty final). Mitigation: short prompt, "think little", explicit word cap, more tokens.

Blocked sources: Moises/Yousician help HTML sits behind a bot check (also in the browser). Solved through the public Zendesk Help Center API, so the content is unchanged. web_extract backend can't extract (search-only), so pages were fetched with curl (python.org Python lacks root certs).

Device incident: one extra Back left the app, and a tap opened Google Messages. It was left via Home immediately, with no interaction. Lesson: check `mCurrentFocus` before every tap after a Back.
