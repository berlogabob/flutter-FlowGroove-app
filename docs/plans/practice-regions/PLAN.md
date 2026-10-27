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
