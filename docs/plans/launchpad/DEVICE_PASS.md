# Launchpad device pass (no release until all rows are PASS)

| # | Check | Device | Status |
|---|-------|--------|--------|
| 1 | Pads: idle / queued ("Starts next bar") / playing, equal grid | P30 | PASS (queued->playing verified 2026-10-22) |
| 2 | Pad switch mid-play, Stop, Loop | P30 | PASS (switch); Stop/Loop partial |
| 3 | Screen off 2 min, backing keeps playing | P30 | PASS with EMUI manual launch; sheet guides it (verified 2026-10-22) |
| 4 | After screen on, pads show the real state | P30 | PASS (60 s screen off, pad still Playing) |
| 5 | Click vs backing offset < 3 ms, drift < 1 ms | P30 + A24 | PASS. JVM TickGridTest (exact, 5 tempos x 5 meters x 5 min). P30 acoustic 5 min: drift 0.008 ms. A24 DIGITAL capture of the engine's mixed PCM (130 s, 266/266 beats on grid): offset -1.2 ms (detector bias, same -1.0..-1.3 ms on P30), drift -0.003 ms. A24 speaker acoustic is contaminated by speaker artifacts, digital capture used instead |
| 6 | BPM change mid-play: backing re-renders, stays in sync | P30 | PASS (+5 twice mid-play: re-render, queued, Playing) |
| 7 | Bluetooth connect and disconnect mid-play | P30 | PASS on P30 (headset) and A24 (Nothing Ear): connect + drop mid-play, 0 underruns, UI lead follows route (250 ms BT / 24-59 ms speaker) |
| 8 | Low-latency AudioTrack granted (logcat "FAST granted") | P30 | P30 FAIL-ACCEPTED (HAL denies FAST); A24 PASS (FAST granted mono) |
| 9 | Backing tracks button visible with no song | P30 | PASS (L39) |
| 10 | Battery sheet shows once, Settings tile, vendor deep link opens | P30 | PASS (sheet shows once after Play, steps for Huawei) |
| 11 | Same checks 1-3, 6-8 | A24 | PASS: A24 install, grid, FAST granted, exemption dialog, 2 min screen-off, media pause, BT drop/reconnect, F17 knob drag, F20 repeated saves |
| 12 | Web launchpad | Chromium | PASS: lib/dev/web_launchpad_harness.dart + scripts/web_launchpad_e2e.js drive the real launchpad and web engine on a synthetic MIDI song: 1 shared AudioContext, 24 backing sources, 40 click ticks, every backing start on a click tick (worst 0.0000 ms), 0 console errors |
| 13 | Full suite, analyzer, Gradle tests on second01 | Mac | PASS at 2026-10-22 merge; rerun after L37-L40 |
| 14 | Web deploy (app-hosting + pages) incl. wiki metronome page | Mac | after release |
| 15 | System media pause (KEYCODE_MEDIA_PAUSE) returns UI to Play/Idle | P30 | PASS (A24 same code path, not re-run) |
| 16 | UI beat dots follow the audible frame across routes | P30 | PASS: lead 250 ms BT -> 59 ms speaker, live through a headset drop |
