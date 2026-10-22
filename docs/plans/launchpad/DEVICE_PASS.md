# Launchpad device pass (no release until all rows are PASS)

| # | Check | Device | Status |
|---|-------|--------|--------|
| 1 | Pads: idle / queued ("Starts next bar") / playing, equal grid | P30 | PASS (queued->playing verified 2026-10-22) |
| 2 | Pad switch mid-play, Stop, Loop | P30 | PASS (switch); Stop/Loop partial |
| 3 | Screen off 2 min, backing keeps playing | P30 | PASS only with EMUI "Manage manually"; needs L37 sheet |
| 4 | After screen on, pads show the real state | P30 | FAIL F16 -> L38 |
| 5 | Click vs MIDI offset < 3 ms, drift < 1 ms / 5 min (L29 diagnostic + scripts/measure_sync.py) | P30 | NOT RUN |
| 6 | BPM change mid-play: backing re-renders, stays in sync | P30 | NOT RUN |
| 7 | Bluetooth connect/disconnect mid-play | P30 | NOT RUN |
| 8 | Low-latency AudioTrack granted (logcat "FAST granted") | P30 | FAIL F12 -> L40 |
| 9 | Backing tracks button visible with no song | P30 | FAIL F10 -> L39 |
| 10 | Battery sheet shows once, Settings tile, vendor deep link opens | P30 | after L37 |
| 11 | Same checks 1-3, 6-8 | A24 | NOT RUN (not connected) |
| 12 | Web: pads, per-bar scheduling, tab hidden 60 s, BPM change | Chrome | NOT RUN |
| 13 | Full suite, analyzer, Gradle tests on second01 | Mac | PASS at 2026-10-22 merge; rerun after L37-L40 |
| 14 | Web deploy (app-hosting + pages) incl. wiki metronome page | Mac | after release |
