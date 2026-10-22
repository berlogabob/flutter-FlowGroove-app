# Launchpad: findings log (device passes feed the task list)

Rule (user, 2026-10-21): any problem found in a test is added to this scope; NO release until the whole set (L01..) is done and device-verified.

## P30 baseline, release 0.27.0 built from second01 (2026-10-21 23:30, ELE-L29, Android 10)

| # | Finding | Evidence | Task |
|---|---------|----------|------|
| F1 | MIDI stops after 31 s (file length) while the click keeps running; not looped | `dumpsys media.audio_flinger`: after ~40 s only the click track is active, MIDI track idle | L04-L23 (bar-slaved loop), L22 |
| F2 | Click AudioTrack is not on the FAST path; ~140 ms output latency; 80 ms buffer | logcat `AUDIO_OUTPUT_FLAG_FAST denied by server; frameCount 3840`; audio_flinger track 442 Flags 0x000, Latency 139.88 ms; HAL write latency avg 59.7 ms | L31 |
| F3 | All 5 tracks titled "Back to black" (only a small role line differs) | mixer screenshot | L32-L34 |
| F4 | Play button is below five tall cards, off screen on open; no position/progress | mixer screenshot, needed 2 scrolls | L26 (pinned transport row) |
| F5 | Mixer header shows metronome BPM 120, not the file's 124 or the song's 123 | mixer screenshot | L21, L26 (status line), L27 |
| F6 | Two separate audio tracks from the app (48 kHz click, 44.1 kHz SoLoud MIDI, 1920 underrun frames on the MIDI one) | audio_flinger track table | whole plan (one stream) |
| F7 | App not on the battery-optimization allowlist | `dumpsys deviceidle whitelist` empty | L28 |
| F8 | OK baseline: screen off 15 s keeps the click alive (foreground service + PARTIAL_WAKE_LOCK `FlowGroove:MetronomeAudio`) | dumpsys power / activity services | re-verify for backing in the final pass |
| F9 | Runner: Gradle verify fails (`gradlew` and the wrapper jar are gitignored, JAVA_HOME env is stale) | ledger L12 | runner fixed (JBR path), worktree files copied |

Not yet measured: click-vs-MIDI offset in ms (needs the diagnostic stem, L29), A24 (not connected), web.

## Final device pass (before any release)
P30 and A24: L29 diagnostic recording (offset < 3 ms, drift < 1 ms / 5 min), pads queued/playing, BPM change mid-play, screen off 2 min, Bluetooth connect mid-play, battery exemption tile, web in Chrome with the tab hidden for 60 s.
| F10 | Release 0.28 build on P30: "Backing tracks" button disabled until a song is loaded; with no song it sits half under the bottom bar and its "Pick a song first" hint is off screen | p30_c.png | L26 (launchpad layout), new task L35 |
| F11 | Pad tap stays "Starts next bar" forever: native backingState/bar events were never forwarded from the click channel handler to PlatformBackingEngine | P30 08:55, pad Verse 1 queued 6 s+ | fixed: backingNativeSink + test/services/backing_native_sink_test.dart |
| F12 | Click AudioTrack still "low latency denied; performanceMode=0" after L31 | logcat FlowGrooveMetronome | open: investigate frame size/sample rate vs FAST requirements (48 kHz, small buffer) |
| F13 | Pads size to their label (ragged widths, small tap targets); "1 bars" grammar; vertical drag over the tempo dial changes BPM while the page scrolls (200 BPM by accident) | p30_h/m.png | L35 (pad grid: equal columns, "1 bar", scroll guard) |
| F14 | Huawei PowerGenie freezes the app ~13-36 s after screen-off even with a foreground service, partial wake lock and the Android doze whitelist: wake lock force-released, AudioTrack stopped, pads reset to Idle. Baseline F8 (15 s) was just under the freeze delay | logcat "Pged-Freezer: Freeze process" 09:01:39, 09:04:28 | L36: EMUI "App launch" guidance tile (settings path: Battery > App launch > Manage manually > Run in background), detect Huawei, never auto-change; then re-test. Needs the user's OK to flip the setting on the P30 |
| F15 | audio_flinger shows tVol=0.000 for the click track right after start (track volume ramp or muted?) | logcat 09:00:11 | verify with L29 diagnostic recording |
| F14b | F14 test matrix on P30 (screen off 70-130 s, backing playing): foreground service + wake lock + deviceidle whitelist = frozen at 13-36 s; + MediaSession (L35) alone = frozen at ~45 s; + EMUI per-app "Manage manually" (Auto-launch, Secondary launch, Run in background all ON) = NO freeze at 130 s, AudioTrack started, MediaSession active state=PLAYING | logcat Pged-Freezer, dumpsys audio/media_session | the EMUI setting is REQUIRED on Huawei; L36/L37 deep link + sheet must guide it; first-run must show it before a concert |
