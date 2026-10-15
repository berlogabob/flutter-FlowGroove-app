# Audit round 3 remediation, pi/ornith only, sequential

## Context
The 2026-10-15 app audit (`audit/2026-10-15-1252-round3/findings.json`, F-001..F-023: 2 sev-3, 9 sev-2, 12 sev-1) found almost everything on the new drum-practice UI. Goal: fix them with small single-file tasks run unattended by the local pi agent (Studio, `ollama/ornith-1.5:35b`), one task at a time, fully traceable. Codex is not used. After plan approval Claude only (a) creates the helper files + worktree, (b) launches the runner, (c) reports when it ends. No Claude code edits during the run.

Lessons baked in (from the drum feature run): pi has no bash tool, so it cannot run tests; pi "passed" M17 without implementing the fix, so every task carries a `must_contain`/`must_not_contain` grep proof, not only tests; pi-run.sh args must be EXISTING files; a task may not touch more than one lib file (+ its existing test file); full-suite gate after each task; never `dart format lib`; a hand-committed task must be written to the ledger.

## Helper files (created at execution start, all under the branch)
- `docs/plans/audit-r3/PLAN.md`: this table + finding→task map (trace).
- `docs/plans/audit-r3/CONTEXT.md`: conventions handed to every pi task as a context file (tokens `MonoPulseColors`/`context.mp`, `package:flowgroove/` imports, trailing commas, `const`, import order, smallest edit, do not reformat file, do not touch `lib/services/audio/engine/*`, `firestore.rules`; update only test assertions the new behavior changes; test harness hints from `test/midi/drum_practice_panel_test.dart`).
- `docs/plans/audit-r3/tasks.json`: tasks `{id,title,finding,files[existing only],prompt,tests[],must_contain[[file,regex]],must_not_contain[[file,regex]],after[]}`.
- `scripts/plan_run.py` v2 (small edit of the existing runner): `PLAN_PI_ONLY=1` (no codex fallback); pi called with `PI_VERIFY=<task verify>` and `PI_MAX_ITERS=3` so pi self-corrects from verify output; verify = `flutter test <tests> | tee` + `dart analyze <file>` (errors only) + grep proofs; then full `flutter test` gate; if the gate fails, ONE more pi attempt with the failing tail in the prompt; rollback on final failure; stop after 3 consecutive failed tasks; `--from R10`/`--only` flags; per-task log `docs/plans/audit-r3/logs/R##.log`; auto-written `docs/plans/audit-r3/STATUS.md` table (id, finding, status, attempts, secs, commit); commit message `fix(audit-r3): R## <title> [F-xxx] via pi`.
- `scripts/plan_status.sh`: prints STATUS.md, last ledger lines, whether the runner is alive.
- `scripts/audit_crawl/` (cap.py, route.py, crawl*.py, nav.sh copied from the scratchpad) so the final device re-audit is one command.
- Worktree `../flutter_repsync_ar3`, branch `fix/audit-r3` from `second01` (main tree is dirty with site files).

## Task list (order = run order; one lib file each)
Edits keep exact existing strings where tests look for them; pi updates only the assertions its change alters.

**A. Theme**
- R01 F-004 `lib/theme/mono_pulse_theme.dart`: add `selectedColor: MonoPulseColors.accentOrange` (+ readable selected label) to `chipTheme` so all ChoiceChip/FilterChip selected states are orange.

**B. Drums sheet** (`lib/widgets/metronome/drum_practice_panel.dart`)
- R02 F-003 empty state: left-aligned block with icon + the exact title `No MIDI patterns yet` + one explanatory line.
- R03 F-003/speed: show Play and the speed chips only when a pattern is loaded; add a `Speed` label above the chips.
- R04 F-004/F-003: `Import .mid` and `New pattern` as an equal-width row (outlined + filled).
- R05 F-011: move Play + speed row above the kit view so Play is visible on first open.
- R06 F-012: selected pattern row: neutral text color, leading radio icon for selected state, 48dp pencil button.
- R07 F-017 (home.dart) see F below.

**C. Grid editor** (`lib/screens/songs/components/drum_grid_editor.dart`)
- R08 F-006 remove the duplicate `Drum pattern` heading, add 12dp gap above Name.
- R09 F-006 bar chips on one row (Row of 4 Expanded chips, labels unchanged).
- R10 F-007 beat columns: background tint instead of orange outline; inactive outline `colors.outline` (>=3:1).
- R11 F-001 horizontal `Scrollbar(thumbVisibility: true)` with a ScrollController around the grid.
- R12 F-001 move the tap-cycle legend above the grid.
- R13 F-005 restructure build: scrollable content in `Expanded`, Play + Save row pinned at the bottom.
- R14 F-005 add optional `ValueNotifier<bool>? dirty` constructor param set true on any edit.
- R15 F-005 (panel file) `_openEditor` route wrapped in `PopScope` + "Discard changes?" dialog using `dirty`.

**D. Shared names, kit view** (`lib/services/audio/midi/drum_map.dart`, `lib/widgets/midi/drum_kit_view.dart`)
- R16 F-009 add `laneLabel()` and `lanePadLabel()` to drum_map.dart (+ test in an existing midi test file).
- R17 F-009 kit view uses them (pads and lane rows).
- R18 F-009 editor lane labels use `laneLabel()` (editor file).
- R19 F-009 pad painter: lighter fill (`surfaceContainerHigh`), 1.5px `outline` stroke, 12sp labels.
- R20 F-010 lane dots 10dp, unlit ring `colors.outline`.
- R21 F-008 M/S chips: 48dp wide, `labelPadding` 14dp, tooltips kept (selected color comes from R01).

**E. Metronome screen**
- R22 F-002 `metronome_screen.dart`: Drums button always shown directly under `Songs & Settlists` (disabled with caption `Pick a song first` when none), above the song card; update `test/midi/drums_button_test.dart`.
- R23 F-013 new file `lib/providers/data/drum_active_provider.dart` (`StateProvider<bool> drumActiveProvider`).
- R24 F-013 `drum_practice_provider.dart` keeps `drumActiveProvider` in step with `state.playing` and pattern name.
- R25 F-013 `metronome_screen.dart` Drums button: filled style + pattern name while active (watches only the light provider, never the drum notifier).
- R26 F-014 `central_tempo_circle.dart` BPM number stays `textPrimary` while playing.
- R27 F-015 same file: sub-label `BPM · double-time?` when bpm >= 240.
- R28 F-018 `time_signature_block.dart` stepper buttons 48 everywhere, one label style.

**F. Other screens**
- R29 F-021 `practice_dashboard_card.dart` `Tap to start` primary text color + chevron.
- R30 F-021 `home_screen.dart` quick-action labels `Add song/Add band/Add setlist`; update `home_quick_actions_test.dart`.
- R31 F-017 `home_screen.dart` rehearsals sheet: demo users see `Sign up to create a band`.
- R32 F-017 `create_band_screen.dart` demo `Sign Up` becomes a FilledButton; update `create_band_demo_test.dart`.
- R33 F-019 `unified_item_card.dart` songs show a muted `-- BPM` placeholder when BPM is missing.
- R34 F-022 song filter sheet (pi greps `Filter Options`): align Major/Minor chips to the gutter.
- R35 F-016 `audio_note_screen.dart` one-line caption about the microphone permission under Record.

**G. Instrumentation (F-023)**
- R36 `analytics_service.dart` add `logDrumPatternImported/Saved/PlayStarted(sync)/SyncToggled` + event constants.
- R37 panel: call them (import, save, play, sync toggle).
- R38 editor: call `logDrumPatternSaved` on save.

**Final (not pi)**: R39 full `flutter test` + `dart analyze` (runner final gate); then Claude builds the APK, installs on the P30, reruns `scripts/audit_crawl` (demo) and the real-account drum smoke, merges `fix/audit-r3` into `second01` only if green.

## Finding trace
F-001 R11,R12 · F-002 R22,R25 · F-003 R02,R03,R04 · F-004 R01 · F-005 R13,R14,R15 · F-006 R08,R09 · F-007 R10 · F-008 R21 · F-009 R16,R17,R18,R19 · F-010 R20 · F-011 R05 · F-012 R06 · F-013 R23,R24,R25 · F-014 R26 · F-015 R27 · F-016 R35 · F-017 R31,R32 · F-018 R28 · F-019 R33 · F-020 DROPPED (Menu sheet looked half-open only because the capture caught the open animation; re-check on device in the final pass) · F-021 R29,R30 · F-022 R34 · F-023 R36-R38. Hit-area claim on song-card icons dropped (already 48dp). Backlog not in this plan: round-2 leftovers (white cold-start frame, tuner labels, login Retry), cell size 36→40 (needs layout redesign), real drum samples, pitched instruments.

## Verification
Per task (runner): targeted `flutter test` files + `dart analyze` errors + grep proofs + full-suite gate; STATUS.md and logs/ for tracing. End to end: runner final gate, APK on P30, `scripts/audit_crawl` recapture of screens 03-33, `findings.json` diffed against round 3, real-account smoke (import, save, relaunch, sync with sheet closed) on Millennium / Summer of '69. Expected runtime ~7-9 h (about 10-15 min per task); runner stops itself after 3 consecutive failures.

## Claude save mode after approval
Claude spends tokens only on: creating the helper files and worktree (one pass), launching `PLAN_PI_ONLY=1 python3 scripts/plan_run.py` in the background (no nohup, check `pgrep` first), waiting for its completion notification, reading STATUS.md, then the device pass and merge. No polling loops, no subagents.


## Final task numbering (generated; supersedes the R-numbers in the table above)

R23 of the plan (drum_active_provider.dart) was created by Claude at setup, so tasks were renumbered R01-R37. Source of truth: tasks.json (gen_tasks.py).

| finding | tasks |
|---|---|
| F-001 | R10, R11 |
| F-002 | R21 |
| F-003 | R02, R03, R04 |
| F-004 | R01 |
| F-005 | R12, R13, R14 |
| F-006 | R07, R08 |
| F-007 | R09 |
| F-008 | R20 |
| F-009 | R15, R16, R17, R18 |
| F-010 | R19 |
| F-011 | R05 |
| F-012 | R06 |
| F-013 | R22, R23 |
| F-014 | R24 |
| F-015 | R25 |
| F-016 | R33 |
| F-017 | R29, R30 |
| F-018 | R26 |
| F-019 | R31 |
| F-021 | R27, R28 |
| F-022 | R32 |
| F-023 | R34, R35, R36, R37 |
