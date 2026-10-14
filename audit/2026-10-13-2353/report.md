# UX/UI Audit — FlowGroove 0.25.0+363 (Android, Huawei P30, Demo account) — 2026-10-14

## Executive Summary
Release verdict: READY WITH FIXES. 26 findings (0 sev-4, 5 sev-3, 12 sev-2, 9 sev-1). Task success 6/7 flows (86%); the one failure is the write path, untestable on the read-only demo. Top issues: blank white ~10s cold-start frame (debug build, re-check on release); Settings theme control wraps 'Dark' to 'Dar/k' and uses an off-brand selected state; tuner and metronome controls are below tap-target minimums.

## Background & Objectives
Commit 40480801, v0.25.0+363 debug arm64 build, installed fresh (old 0.23.0 had a different signing key; uninstalled with user consent). Triggered by /app-audit.

## Methodology
22 screens captured by adb screencap + uiautomator dump (Maestro cannot run on EMUI). 7 manual flows (not Maestro YAML). Frameworks: Nielsen 10, UX laws, visual design, design system, 5 states; measure.py. NOT COVERED: real-account data, write flows, event sharing/personal events (0.25.0 headline), concert mode, offline/error states, Sign Up, web, iOS, tablet. Subagents viewed only a subset of screenshots; some findings rest on measurements.json (e.g. tap-target nodes may be label boxes, not true targets).

## Metrics
| Metric | Value |
|---|---|
| Task success rate | 86% (6/7) |
| Avg steps per flow | 3.4 |
| Findings sev 4/3/2/1 | 0/5/12/9 |
| Defect density | 1.2 findings per screen |

## Key Findings

### Severity 3
**F-001 · sev 3 · ST-LOAD · launch** — First frame after cold start is blank white ~10s, no splash/spinner; app is dark-themed (debug build, unverified on release). Evidence: `screens/android/launch.png`, flows-results: first-launch-to-demo-home. Fix: Native dark splash + progress; re-measure on release.
**F-002 · sev 3 · DS-FORM-1 · settings** — Theme segmented control wraps selected 'Dark' to 'Dar/k'; selected state is flat grey, not the orange accent used by chips/toggles. Evidence: `screens/android/settings.png`. Fix: Equal flexible segment widths, drop checkmark or shrink; use the shared selected-state token.
**F-003 · sev 3 · DS-BTN-1 · tool_tuner** — Three different mode-switch styles; Auto/Manual toggle 26dp tall; dial note-select targets ~10dp on one axis. Evidence: `screens/android/tool_tuner.png`, Auto 88.1x26.0, Manual 103.3x26.0; note selectors 47.7x10.1. Fix: One segmented component; pad note hit areas to >=44dp.
**F-004 · sev 3 · DS-A11Y-1 · tool_metronome** — Beat dots 32.5dp wide; 'Subdivision' label smaller than 'Beats'; controls on mismatched grids; badges overlap + buttons. Evidence: `screens/android/tool_metronome.png`, Main beat 1-4 32.5x52.0; near-misses 3-4px; group 17 vs 9. Fix: Beat targets >=44dp, one label style, shared grid.
**F-005 · sev 3 · H5 · band_create** — Demo user gets a fillable Create Band form; the read-only reason appears only after arrival as a red error card; Create Band disabled without explanation. Evidence: `screens/android/band_create.png`. Fix: Gate the entry (locked state / Sign Up prompt) before opening the form; use informational, not error, styling.

### Severity 2
**F-006 · sev 2 · LAW-FITTS-1 · home** — Demo-banner 'Sign Up' action is 69.7x26dp, top edge, present on every screen. Evidence: `screens/android/home.png`, 69.7x26.0 (min 44), flagged on 15 of 20 screens. Fix: Padded >=48dp button or whole-banner tap; make banner dismissible.
**F-007 · sev 2 · IXD-PRED · song_detail** — Song opens on the Edit tab with form fields and a Save Changes bar demo users cannot use; reading a song lands on a form. Save bar overlaps a clipped card. Evidence: `screens/android/song_detail.png`. Fix: Open viewers/demo on Sheet; hide or explain Save; separate the sticky footer.
**F-008 · sev 2 · H4 · song_detail / song_lab / settings** — Selected segment is flat grey in Edit/Sheet/Lab, Entries/Tasks and Theme, but orange on Songs chips. Evidence: `screens/android/song_detail.png`. Fix: One selected-state style for all segmented controls and chips.
**F-009 · sev 2 · H8 · song_lab** — Empty Lab shows two segmented controls, two unlabeled icon buttons and five + chips before a near-edge-to-edge empty-state paragraph. Evidence: `screens/android/song_lab.png`, group 16 vs 9. Fix: Collapse add-actions into one menu, label icons, pad empty-state text 24-32dp.
**F-010 · sev 2 · HICK-1 · tab_songs** — Header stacks search+sort (fused in one box), clipped tag chips ('80s' cut), Key/BPM filters and count: ~600px before the first song; orange practice icon on cards unlabeled; Ironman card has a BPM gap. Evidence: `screens/android/tab_songs.png`, 52 elements. Fix: Separate search/sort, collapse filters into one sheet, tooltip the icon, tighten cards.
**F-011 · sev 2 · ST-ERROR · all** — No error/offline state exercised (NOT COVERED). Evidence: `screens/android/home.png`. Fix: Test airplane mode and bad input on list, login, band load.
**F-012 · sev 2 · FLOW-1 · quick_add_song / band_create** — Write flow incomplete: demo is read-only, so save/success feedback is unverified. Evidence: `screens/android/quick_add_song.png`, flows-results: create-song-create-band-write-path passed=false. Fix: Run on a real test account; confirm demo Save gives explicit feedback.
**F-013 · sev 2 · DS-NAV-1 · band_detail** — Detail screens swap the 5-tab bar for Back/Title/Menu (cells 33.6dp tall); header name truncated ('The Cover Collec...') yet repeated in the bar; ~40% empty space below content. Evidence: `screens/android/band_detail.png`, Back 93.2x33.6, Menu 93.2x33.6 (min 44). Fix: Full 56dp cells as targets, let name wrap, fill the empty area or add a CTA.
**F-014 · sev 2 · DS-SPACE-1 · band_create** — Three different left margins on one screen (~63px form, ~73px error card); other screens ~42px. Evidence: `screens/android/band_create.png`. Fix: Single page-gutter token.
**F-015 · sev 2 · DS-ICON-1 · quick_add_song** — Section icons inconsistent in weight/meaning; bare dash for unset Key & BPM; placeholders vs floating labels differ from the Edit form. Evidence: `screens/android/quick_add_song.png`. Fix: One icon family; show 'Not set'; floating labels in both forms.
**F-016 · sev 2 · VD-COL-1 · home** — Orange used on all tile icons, banner, links and active tab, so the accent no longer signals primary action; weekly card has no CTA, day labels tiny and low contrast. Evidence: `screens/android/home.png`. Fix: Neutral tile icons; add Start practice button; raise label contrast.
**F-017 · sev 2 · VD-HIER-2 · tool_tuner** — Note labels collide with ticks (G#); duplicate Listen controls (chip + FAB); tiny 'A4 440' caption. Evidence: `screens/android/tool_tuner.png`, near-misses 3/5/6px; group 12 vs 9. Fix: Consistent radial offset, one listen control.

### Severity 1
**F-018 · sev 1 · NAV-5 · tool_rehearsals** — Rehearsals is per-band but listed under Tools; opens a band-picker sheet that clips against the bottom nav. Evidence: `screens/android/tool_rehearsals.png`. Fix: Move to band context or surface next rehearsal on Home.
**F-019 · sev 1 · NAV-1 · tab_songs / tab_bands / tab_setlists** — Top-level tabs have no title; band/setlist card text truncated; dates dd.mm.yyyy in English UI; demo setlist 'тест' (test data) has no date. Evidence: `screens/android/tab_setlists.png`. Fix: Add titles, locale date format, clean demo seed.
**F-020 · sev 1 · ST-EMPTY · song_sheet / band_rehearsals** — Demo songs have no lyrics/chords so the core Sheet is never shown populated; empty rehearsals state has no action; CTAs dead-end in demo. Evidence: `screens/android/song_sheet.png`. Fix: Seed demo with lyrics/chords; add Propose rehearsal for editors; explain demo lock.
**F-021 · sev 1 · H2 · tool_practice / tool_recorder** — Hint 'song card -> Song Lab' doesn't match the real path (song page > Lab tab); Recorder empty copy 'Link takes to songs later...' is unclear; Quick start labels differ in size. Evidence: `screens/android/tool_practice.png`. Fix: Reword to real paths; one label style.
**F-022 · sev 1 · VD-RESP-1 · setlist_detail** — Titles/artists wrap because key badges take variable width; badge edges ragged. Evidence: `screens/android/setlist_detail.png`. Fix: Fixed-width key pill, ellipsize artist.
**F-023 · sev 1 · VD-HIER-1 · login** — Outlined Try Demo competes with filled Sign In; helper text small mid-grey; link targets small. Evidence: `screens/android/login.png`, Sign Up 69.7x26.0. Fix: Make Try Demo secondary; lighten helper text; 44dp link targets.
**F-024 · sev 1 · LAW-FITTS-1 · settings / song_detail rows** — Row semantics bounds only 6.5-7.6dp (analytics toggle, Notes) - likely clipped nodes. Evidence: `screens/android/settings.png`, 346.7x6.5; 355.3x7.6. Fix: Single 48dp SwitchListTile rows; fix semantics bounds.
**F-025 · sev 1 · LAW-MILLER-1 · song_lab / tool_metronome / tool_practice** — Groups exceed 9 items. Evidence: `screens/android/song_lab.png`, 16 / 17 / 11 vs 9. Fix: Chunk into collapsible sections.
**F-026 · sev 1 · FLOW-3 · all** — No backgrounding/rotation/system-back pass. Evidence: `screens/android/home.png`. Fix: Run an interruption pass on song, tuner, recorder.

## Recommendations
1. Sev-3: splash + release-build load measurement; fix Theme segmented control; unify segmented/selected-state component (clears 3 findings); 44dp targets on tuner/metronome; gate Create Band for demo.
2. Batch design-system debt: gutter token, icon family, one selected-state style, accent restraint on Home.
3. Seed demo with lyrics/chords and remove 'тест'.
4. Coverage gap: audit personal events/sharing on a real test account; add airplane-mode pass. HEART instrumentation: Task success via existing analytics screen_view funnel (song create, setlist open).

## Trend vs previous run
Previous 2026-07-18 run used a real account and different criterion IDs; (criterion, screen) overlap is 1 of 21, so fixed/new/regressed is not meaningful. Not computed.

## Appendix
See screens.md, flows-results.json, measurements.json (22 screens, 183 numeric flags).