# Plan tracker — audit 2026-11-13 + Flutter 3.50 migration

Released as 0.34.1+378 on 2026-11-14 (Android GitHub release, app.flowgroove.app, github.io). Generated from PROBLEMS.md; details and evidence there, task-level trace in TRACE.md.

Closed 60 of 72.

## Open / deferred

- [ ] M-10 — Wasm interop warning lib/services/audio/backing_engine_web.dart:14 — _open (fix reverted in 0.34.1: it broke the web build, see N-014; Wasm dry-run warning is back)_
- [ ] M-11 — Same-major dependency bumps — _deferred (upgrade reverted: broke the release build, see N-012; redo one package at a time with an APK build gate)_
- [ ] M-12 — Major dependency bumps (Firebase family, file_picker 13) — _not started (major dependency bumps; need APK-build gate)_
- [ ] A-03 — measure.py reports 0 flags on adb hierarchies (skill file, report only) — _not started (measure.py diagnosis, skill file outside repo)_
- [ ] F-003 — Add Song: The optional autofill search is the first large field and resembles the required Title input. The CR — _partial: Title-first verified; search box still icon-only, continued in N-009_
- [ ] F-004 — Setlist → testo tiras: Four of six entries say only Unavailable song. Their titles and the reason for unavaila — _partial: reason text added and verified; last-known titles are not stored on setlist items, so they cannot be shown (def_
- [ ] F-006 — Add Song → offline search: After entering a search offline and waiting eight seconds, the form shows no result — _not verified: offline search could not be driven by adb (query not accepted); no fix made_
- [ ] F-017 — Progress → recent sessions: Most visible history entries say Removed song without identifying information; som — _deferred: history rows have no stored song title for removed songs (needs data model change)_
- [ ] F-033 — Metronome → song sections: Section cards use colored borders to distinguish categories, but repeated labels su — _deferred: design choice, still present on device_
- [ ] F-039 — Recorder: The orange Record button is markedly rounder than the orange creation buttons; the theme specifies a — _deferred: design choice (sev 1)_
- [ ] N-001 — Finish F-008 (Metronome: Two rows of circles and plus/minus controls lack labels for beats and subdivisions; t — _deferred: no safe code change found (last metronome label sub-task)_
- [ ] N-015 — Setlists: swipe-left on a setlist row deletes it immediately with no confirmation dialog (songs ask first); un — _open_

## Closed

- [x] M-01 — Gradle/AGP/Kotlin upgrade for Flutter 3.50
- [x] M-02 — Raise to Flutter template versions: Gradle 9.5.0, AGP 9.3.1, Kotlin 2.4.20
- [x] M-03 — Exclude audit/** in analysis_options.yaml
- [x] M-04 — pubspec environment sdk ^3.14.0
- [x] M-05 — 5 single deprecations (RadioGroup x2, onReorderItem, readAsBytes, withValues)
- [x] M-06 — 275 flutter/material.dart imports -> material_ui (dart fix)
- [x] M-07 — Remaining dart fix codes in lib/ and test/
- [x] M-08 — 54 analyzer warnings in lib/ and test/
- [x] M-09 — Legacy analyzer plugin deprecation warning
- [x] M-13 — Full re-crawl on the Flutter 3.50 build
- [x] A-01 — Move crawl.py/flows.py into scripts/audit_crawl, drop stale route lists
- [x] A-02 — Crawler captures launcher when app not foreground
- [x] A-04 — Crawler must not tap permission dialogs
- [x] F-001 — This week → Continue: Continue from Progress opens a blank content area with only bottom n
- [x] F-002 — Songs → song actions: Delete is absent from the song detail, editor, and list-row menus. T
- [x] F-005 — Tuner: Note names and tick marks around the dial are nearly white against pale gray and di
- [x] F-007 — Add Song → Key & BPM: Each row has two unlabeled dropdowns displaying a dash, and Original
- [x] F-008 — Metronome: Two rows of circles and plus/minus controls lack labels for beats and subdivisi
- [x] F-009 — Tuner: The idle instruction says Tap Listen, but a top Listen control and a large micropho
- [x] F-010 — Recorder: Playback controls are unlabeled and repeated recording menus share the generic S
- [x] F-011 — Songs: Search has no accessible label, and repeated Metronome and More actions do not iden
- [x] F-012 — Bands: Search and several band rows are unlabeled clickable nodes, and repeated View Songs
- [x] F-013 — Setlists: Search and setlist rows are unlabeled clickable nodes, and repeated metronome an
- [x] F-014 — Add Song: Autofill, Title, and Artist are reported as unlabeled clickable nodes, preventin
- [x] F-015 — Create Band: Band Name and Description are reported as unlabeled clickable nodes despite v
- [x] F-016 — Create Setlist: The Setlist Name input is an unlabeled clickable node; the adjacent collap
- [x] F-018 — Song sheet → stage mode: The fullscreen control disappears after entering stage mode, and 
- [x] F-019 — Song sheet → transpose: After transposing down, the control reads -1 while the header stil
- [x] F-020 — Add Song → Metronome Settings: Expanding Metronome Settings leaves its controls below the 
- [x] F-021 — Songs → Key / BPM filter: The filter offers sharp note names only while song cards display
- [x] F-022 — Song editor: The empty editor instructs users to type ChordPro or use Import / Add, but ne
- [x] F-023 — Songs → tag filters: Adjacent tag filter chips have touch targets shorter than 48 dp.
- [x] F-024 — Add Song → Tags: The ready, easy, and hard controls are partly obscured by the fixed Save 
- [x] F-025 — Setlists → testo tiras: Play controls for available songs are unlabeled in the accessibili
- [x] F-026 — Songs → Metronome: Fixed playback controls partially cover the Backing tracks button, obsc
- [x] F-027 — Songs → Key / BPM filter: Bottom navigation covers the lower part of the filter sheet, inc
- [x] F-028 — Songs → search: The search placeholder is truncated to Search s… while the adjacent sort c
- [x] F-029 — Song detail → Basketcase: The song title is truncated in both the header and bottom bar, s
- [x] F-030 — Progress → Tools: The Metronome label is much smaller than Tuner and Recorder despite thei
- [x] F-031 — Progress → recent sessions: Tightly packed session names run into duration information or 
- [x] F-032 — Bands: The floating add button overlaps and partly obscures the lower band's overflow acti
- [x] F-034 — Add Song → Song Structure: The No sections yet empty-state text is very pale against its l
- [x] F-035 — Home → This week: The card says Tap to start but opens Progress, where starting practice r
- [x] F-036 — Progress → homework: The captured screen shows Loading homework… without a way to distingu
- [x] F-037 — Add Song → expanded sections: Icons for Key & BPM, Links, Song Structure, and Notes change
- [x] F-038 — Songs → sort menu: The sort control and options use a serif face while adjacent controls u
- [x] F-040 — More: More represents Metronome with a stopwatch while Home and Progress use a gauge-style
- [x] N-002 — Finish F-012 (Bands: Search and several band rows are unlabeled clickable nodes, and repea
- [x] N-003 — Finish F-013 (Setlists: Search and setlist rows are unlabeled clickable nodes, and repeate
- [x] N-004 — Finish F-035 (Home → This week: The card says Tap to start but opens Progress, where start
- [x] N-005 — Finish F-040 (More: More represents Metronome with a stopwatch while Home and Progress use
- [x] N-006 — Tuner > Select Instrument: the 'Standard' tuning label wraps mid-word ('Standar' / 'd')
- [x] N-007 — Add Song > Metronome Settings: beat-pattern circles expand to most of the screen width, on
- [x] N-008 — Tuner > Tone: the selected-note marker overlaps and obscures the C# label on the dial
- [x] N-009 — Add Song (rest of F-003): the web-search/autofill box below Title+Artist is icon-only with
- [x] N-010 — Add Song > Tags (F-024, still open on device): ready/easy/hard chips partly hidden behind 
- [x] N-011 — Bands (F-032, still open on device): floating add button overlaps the last visible band ro
- [x] N-012 — Same-major dependency upgrade (M-11) pulled record_android 2.3.0, which fails to compile i
- [x] N-013 — REGRESSION (device-confirmed on final build): tapping a song card in the Songs list no lon
- [x] N-014 — Web build broken on the merged branch: M-10 (ornith) rewrote the AudioContext check and M-
