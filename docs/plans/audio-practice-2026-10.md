# Audio & practice plan (2026-10-28)

Owner decisions: one recording screen (modes Listen / Map / Practice), notes are
time-based `notes: [{ms, text}]`, trim = skip by default + explicit "Shrink file",
quality is "practice, not hi-fi", long files are cut BEFORE upload, no limit raise.

| # | Item | Who | Status |
|---|------|-----|--------|
| A1 | Trim/split upload to a NEW object name, save entry, then delete old (no dead URL on failure) | codex | done a044a16b |
| A2 | Persistent audio file cache keyed by storage path (immutable after A1); all players/decoders use it; `cacheControl: public, max-age=1y` on upload (web HTTP cache) | codex | done a044a16b |
| A3 | Click & drums keeps the pickup before the first downbeat (pad to whole bar, shift spans) | claude | done (by-ear check still owner's) |
| A4 | One analysis PCM (22.05 kHz) for fine-tune + analysis; persisted next to the cached file | codex | done a044a16b |
| A5 | Long import (> 20 min): suggest cutting into songs before upload, reusing slice detection on the local AAC; upload each part as its own take | codex | done 09e092c1 (128k imports) |
| A6 | Tempo octave: prefer the detector candidate matching song BPM (x0.5/x2) | claude | done, device: 170.0 with song BPM 170 |
| A7 | Waveform RMS instead of max peaks (mastered tracks) | codex | done, Kotlin compile checked in A15 |
| A8 | Duplicate songs ("inocente" x2): find cause | claude | not a dup: empty personal song (2026-10-26) + band copy at 170 BPM; take went to the personal one |
| A9 | Notes field `notes: [{ms,text}]` with body-line fallback | codex | done |
| A10 | Unified recording screen: split practice_regions_screen into widgets (no behavior change), then move AudioNoteScreen features in, delete AudioNoteScreen | codex | done 3fd88783 + 924dfcd7 (AudioNoteScreen deleted) |
| A11 | iOS AAC decode (AVAudioConverter) for analysis | later | deferred by owner (Android first) |
| A12 | Downbeat: choose bar phase by low-band (kick) comb, fallback full band | codex | done |
| A13 | Old builds (0.31.2 on P30/web) write notes into body; once an entry has `notes`, those edits are hidden. Ship Android + web together | release | last: release Android + web together after all items |
| A14 | LabAudioPlayer fetches via http directly; use audioBytesFetcherProvider (testable) | ornith | done |
| A15 | Device pass on A24 | claude | done 17:25: unified screen, ms note, title save, offline reopen (cache+pcm), 26 min file -> 9 correct cuts, 2-part upload, split (old object deleted, new has cacheControl), delete. Not checked: pickup (by ear), octave (song has no BPM), Shrink file |
| A16 | Listen/Map/Practice tabs | owner | no tabs, keep Play + Shift + Note — closed |
| A17 | Title field used onTapOutside, which never fired in the app bar; now saves on focus loss — verify on device | claude | in A15 |
| A18 | Old imports keep max-peak waveform (solid block); re-derive peaks (RMS) once on open when entry lacks a `peaksRms` flag | codex | done |
| A19 | Title edit lost if keyboard closed with Back and screen left (focus never lost); save on dispose too | claude | done |
| A20 | Setup wizard auto-opens on every visit until sections exist; open once per entry (remember dismissal) | codex | done |
| A21 | Recorder cap 25 min | owner | keep (less Firebase load) — closed |
| A22 | toAac hung on a 26 min m4a: encoder never signalled EOS, sheet stuck on "Converting…" at 0% CPU; idle timeout added | claude | did not reproduce on retest; guard committed |
| A23 | Shrink file / split / share / delete not yet exercised on device (destructive on owner data) — test on a throwaway take | claude | done 18:05: split, delete, Shrink (0:18->0:16) on device |
| A24 | Parts of a long file get a 1/N slice of the whole file's 200 bars (Part 2 had ~23 bars); re-derive peaks per part on upload or backfill when peaks < 100 bars | claude | done (re-derive when < 100 bars) |
| A25 | Transport row has an empty third button slot on the unified screen | claude | done: slot is now Note |
| A26 | Lab card Delete confirms like the screen | codex | done |
| A27 | Waveform contrast stretch (display) | codex | done |
