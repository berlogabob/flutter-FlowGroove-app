# Launchpad device pass (no release until all rows are PASS)

| # | Check | Device | Status |
|---|-------|--------|--------|
| 1 | Pads: idle / queued ("Starts next bar") / playing, equal grid | P30 | PASS (queued->playing verified 2026-10-22) |
| 2 | Pad switch mid-play, Stop, Loop | P30 | PASS (switch); Stop/Loop partial |
| 3 | Screen off 2 min, backing keeps playing | P30 | PASS with EMUI manual launch; sheet guides it (verified 2026-10-22) |
| 4 | After screen on, pads show the real state | P30 | PASS (60 s screen off, pad still Playing) |
| 5 | Click vs backing offset < 3 ms, drift < 1 ms / 5 min | P30 | PASS acoustic (release build, SYNC_TEST): offset -1.04 ms, drift +0.97 ms over 300 s; frame-exact JVM proof TickGridTest; A24 pending |
| 6 | BPM change mid-play: backing re-renders, stays in sync | P30 | PASS (+5 twice mid-play: re-render, queued, Playing) |
| 7 | Bluetooth connect and disconnect mid-play | P30 | PASS after F18 fix (A24 pending unlock) |
| 8 | Low-latency AudioTrack granted (logcat "FAST granted") | P30 | P30 FAIL-ACCEPTED (HAL denies FAST); A24 PASS (FAST granted mono) |
| 9 | Backing tracks button visible with no song | P30 | PASS (L39) |
| 10 | Battery sheet shows once, Settings tile, vendor deep link opens | P30 | PASS (sheet shows once after Play, steps for Huawei) |
| 11 | Same checks 1-3, 6-8 | A24 | PARTIAL: A24 installs, 3-col grid, FAST granted, exemption dialog, 2 min screen-off, lock-screen media control, media pause stops cleanly. Bluetooth drop/connect and acoustic offset on A24 pending (A24 face-locked) |
| 12 | Web: pads, per-bar scheduling, tab hidden 60 s, BPM change | Chrome | COMPILES; browser smoke PASS (demo login, metronome Play, 0 console errors); MIDI backing not exercisable on web without a login + MIDI song |
| 13 | Full suite, analyzer, Gradle tests on second01 | Mac | PASS at 2026-10-22 merge; rerun after L37-L40 |
| 14 | Web deploy (app-hosting + pages) incl. wiki metronome page | Mac | after release |
| 15 | System media pause (KEYCODE_MEDIA_PAUSE) returns UI to Play/Idle | P30 | PASS (A24 same code path, not re-run) |
| 16 | UI beat dots follow the audible frame across routes | P30 | PASS: lead 250 ms BT -> 59 ms speaker, live through a headset drop |
