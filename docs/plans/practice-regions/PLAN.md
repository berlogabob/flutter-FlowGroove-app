# Practice regions — tracker

Registry: `docs/plans/systemic-ux/activity.json` issue `PRACTICE-REGIONS`.

- [x] P1 regions, split/name/drag, loop + transition run, speed, pre-roll, tempo grid — `a2ac67a4`
- [x] PR-ENTRY Lab card: "Practice regions" menu item + region count
- [x] PR-MAP "Use as song map": builds sections when empty, else links n-th occurrence; never rewrites
- [x] PR-WAVE Waveform for imported files: web decodeAudioData (all formats), native WAV + SoLoud (mp3/flac/ogg; m4a none) — needs device check
- [x] PR-LOG Logbook shows "Song · Verse 2 → Chorus · N loops" (≥10 s per loop selection). Continue card still opens the song, not the region (no id lookup for lab entries)
- [x] PR-SYNC "Play with click & drums": song decoded into the click engine as a stem (+ song's first Lab drum pattern), regions → bar spans, loop switches on the bar; whole-number BPM, 100% speed; mp3/wav/flac native, all formats web — timing unmeasured on device
- [ ] PR-DEVICE Owner check on P30 + Chrome (by ear)

## Markers (PRACTICE-MARKERS)
- [x] PM-STUTTER split restarted/moved the loop — `e633176f`
- [x] PM-MARK one-tap Add marker, no naming sheet — `fcc88372`
- [x] PM-LISTS Markers / Regions tabs (seek, delete, loop, rename) — `fcc88372`
- [x] PM-ZOOM Fine-tune sheet: ±1 s zoom, drag, ±1/10 ms, ±1 beat, snap off/bar/beat/zero-crossing, audition
- [ ] PM-AUTO auto grid + sections: grid works (librosa), sections weak; allin1 needs Linux
- [ ] PM-DEVICE owner by-ear check

## MPC control (PRACTICE-MPC)
- [x] MPC-LOCAL no stutter on region select: local temp copy, pause→clip→play — `59418f29`
- [x] MPC-ANALYSIS on-device estimateGrid + detectOnsets (Back to Black 123.5 BPM) — `3e1393d4`
- [x] MPC-SLICE Auto slice: suggest grid, every N bars, chop by transients — `f4d9d2d6`
- [x] MPC-PADS region pads, tap = loop, hold+tap = run — `673ca935`
- [x] MPC-JOG jog wheel in fine-tune (speed-scaled ms, beat mode)
- [x] MPC-RELEASE 0.30.2+371 web (app.flowgroove.app) + Android (GitHub release, P30 launch)

## Redesign (PRACTICE-UX)
- [x] UX-CUE embedded markers: WAV cue/labl/ltxt, MP3 ID3 CHAP — `d0457c6e`
- [x] UX-MODES Practice (waveform, pads, one transport row) / Edit behind pencil; lists dropped — `17329b57`
- [x] UX-WIZARD setup wizard: Tempo → Sections (file markers / every N bars / by ear) → Names
- [x] UX-RELEASE 0.31.0
