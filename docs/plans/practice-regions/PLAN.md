# Practice regions — tracker

Registry: `docs/plans/systemic-ux/activity.json` issue `PRACTICE-REGIONS`.

- [x] P1 regions, split/name/drag, loop + transition run, speed, pre-roll, tempo grid — `a2ac67a4`
- [x] PR-ENTRY Lab card: "Practice regions" menu item + region count
- [x] PR-MAP "Use as song map": builds sections when empty, else links n-th occurrence; never rewrites
- [x] PR-WAVE Waveform for imported files: web decodeAudioData (all formats), native WAV + SoLoud (mp3/flac/ogg; m4a none) — needs device check
- [x] PR-LOG Logbook shows "Song · Verse 2 → Chorus · N loops" (≥10 s per loop selection). Continue card still opens the song, not the region (no id lookup for lab entries)
- [x] PR-SYNC "Play with click & drums": song decoded into the click engine as a stem (+ song's first Lab drum pattern), regions → bar spans, loop switches on the bar; whole-number BPM, 100% speed; mp3/wav/flac native, all formats web — timing unmeasured on device
- [ ] PR-DEVICE Owner check on P30 + Chrome (by ear)
