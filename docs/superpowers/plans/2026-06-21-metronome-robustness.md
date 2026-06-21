# Metronome Robustness & Stability Plan

> Created 2026-06-21. Goal: fix the laggy-click + Bluetooth-stops-playing bug and harden the
> metronome, **inspired by Tack (`~/Documents/GitHub/tack/tack-android`)** best practices — not copied.
> Hard constraint: **a live concert in ~1 week** (target usable build by **2026-06-27**).

## Context (from our investigation)

Root causes found in our repo (see memory `metronome-bluetooth-route-bug`):
1. **BT stops playback (showstopper):** active engine is the PCM timeline (`enablePcmTimelineEngine=true`)
   feeding a SoLoud `setBufferStream`. `SoLoud.instance.init()` binds miniaudio to ONE output device at
   start; a BT connect/disconnect swaps the device → stream dies. Nothing listens for route changes; the
   feed timer keeps writing to a dead stream → permanent silence. `BufferingType.released` never resumes.
2. **Laggy click:** BT A2DP latency (120–300 ms) + 150 ms prebuffer, and the **visual** pulse runs on a
   separate Dart `WallClockScheduler` from the audio → sound lags the on-screen beat by ~250–450 ms.
3. **Audio-focus is a dead stub:** `AudioFocusManager` calls `MethodChannel('com.flowgroove/audio')` but
   no native handler is registered → no real focus/interruption handling.

What is **already good** (don't rebuild): our PCM timeline places clicks at exact sample offsets
(Tack practice #2), and `WallClockScheduler` already does absolute-time drift correction via
`_nextTargetMs` (Tack practice #4). The legacy native `AndroidMetronomeEngine` (SoundPool + ToneGenerator,
`MainActivity.kt`) already exists, uses absolute-time `nextTickAtNanos` scheduling, and — being SoundPool
on `USAGE_MEDIA` — **follows the system audio route automatically** (survives BT).

## What Tack teaches (verified, `tack-android` @ 916ef881)

From `docs/analysis/metronome_best_practices_for_dart.md` + `..._architecture_for_redesign.md`:
- **3-layer split by who-may-block:** scheduler (decisions) · bridge (FFI + audio focus + load) ·
  native real-time render engine. Keep the boundary even in Dart.
- **Native low-latency engine** (Oboe, `PerformanceMode::LowLatency`, `SharingMode::Exclusive`) — not a
  high-level player. Hot path = one atomic; sounds pre-loaded, triggered by index (cold/hot split).
- **Voice pool + stealing** so overlapping ticks don't click.
- **Background stream-disconnect recovery** (`restartThreadLoop`, `onErrorAfterClose`) — rebuild the
  stream OFF the audio thread on device change. ← our exact BT gap.
- **User-calibratable latency offset** (`LatencyDialogUtil`) — cheap, big perceived-accuracy win.
- **Audio focus** ducking/mute via OS focus listener.
- Improve on Tack: don't make the scheduler a god class; share **one** engine across platforms.

Our PCM-timeline path is conceptually Tack's Layer-3-in-Dart but SoLoud doesn't do disconnect recovery,
so on Android the route-robust answer is either (a) add recovery, or (b) use the native SoundPool engine
that already follows the route.

---

## Phase 0 — Concert-Safe Stabilization  ⏰ DUE 2026-06-27  (must-have)

> Objective: metronome plays reliably through Bluetooth headphones AND phone speaker for a full set,
> with click close enough to the beat to play to. Lowest-risk changes only. No architecture rewrites.

Primary lever (decide at task 0.1): **route the Android metronome through the existing native SoundPool
engine** (which already survives BT) instead of the SoLoud buffer stream.

- [ ] **0.1 Reproduce on-device** — confirm: (a) speaker-only works, (b) connecting BT mid-play kills
      sound, (c) starting with BT already connected. Record latency feel. *Gate: bug reproduced.*
- [ ] **0.2 Switch default Android engine to native SoundPool path** — set
      `MetronomeFeatureFlags.enablePcmTimelineEngine = false` so the primary client becomes
      `PlatformMetronomePlaybackClient` → `AndroidMetronomeEngine` (SoundPool, route-following).
      *Acceptance: BT connect/disconnect mid-play does NOT stop sound.*
- [ ] **0.3 If 0.2 regresses timing/quality**, instead keep PCM timeline but add minimal
      **disconnect recovery**: detect stream death / route change and `stop()→deinit()→init()→rebuild
      stream→resume at current tick` (Dart-side, triggered by an Android `AudioDeviceCallback`).
- [ ] **0.4 Verify haptics + count-in still fire** on the chosen path (band/setlist load → play).
- [ ] **0.5 On-device acceptance run:** 10-min continuous play on BT + speaker, connect/disconnect
      headphones 5× mid-play, switch songs from setlist. *Gate: zero dropouts.*
- [ ] **0.6 Concert-ready checklist (below) all green; build installed on performance phone.**

**Phase 0 acceptance / Concert-Ready Gate**
- [ ] Plays continuously ≥10 min on Bluetooth without stopping
- [ ] Survives 5 BT connect/disconnect cycles mid-play (auto-recovers within ~1 s)
- [ ] Plays on phone speaker as fallback
- [ ] Tempo + accent audibly correct; no drift over 5 min
- [ ] Setlist song load applies BPM correctly (verified earlier trace path)
- [ ] Installed + retested on the actual concert device

---

## Phase 1 — Latency & Visual Sync Polish  (post-concert, ~1 wk)

> Objective: make it *feel* tight — kill the audio/visual lag and let the user dial out device latency.
> Adopts Tack practices #5 (latency calibration) and the audio/UI clock-separation fix.

- [ ] **1.1 User latency-offset setting** (Tack #5): a slider (ms) persisted in prefs; subtract it when
      scheduling clicks. Wire into both engines. Add a simple "tap to calibrate" later.
- [ ] **1.2 Query/estimate output latency** and offset the UI `_uiScheduler` so the on-screen pulse
      matches the audible click on BT (don't reset visual to audio clock yet — just offset).
- [ ] **1.3 Detect BT route active** (native) and apply a larger default offset on BT vs speaker.
- [ ] **1.4 Acceptance:** with BT, visible pulse and click coincide within ~30 ms perceptually.

---

## Phase 2 — Engine Robustness  (post-concert, ~1–2 wk)

> Objective: make the chosen engine glitch-proof at fast tempos/subdivisions and on any device change.

- [ ] **2.1 Voice overlap** (Tack #7/3b): ensure fast tempos/subdivisions don't hard-cut prior clicks
      (SoundPool maxStreams ≥ 4, or voice pool in native render path).
- [ ] **2.2 First-class disconnect recovery** on whichever engine ships (mirror Tack
      `restartThreadLoop`/`onErrorAfterClose` semantics; rebuild off the audio thread).
- [ ] **2.3 Underrun watchdog** (if PCM timeline retained anywhere): detect stream end → re-prime or
      fall back to native, never go silently dead.
- [ ] **2.4 Implement the native audio-focus handler** (`com.flowgroove/audio` +
      `OnAudioFocusChangeListener`): duck on transient, pause/resume on calls (Tack §5). Removes the
      dead-stub path.
- [ ] **2.5 Tests:** unit-test the route-change/recovery *handler logic* with a fake engine (device
      audio itself stays a manual on-device check).

---

## Phase 3 — Strategic Native Engine + Cleanup  (later, optional, ~2–4 wk)

> Objective: match Tack's quality ceiling and reduce platform-specific debt. Only if Phases 0–2 leave
> residual latency/quality gaps. High effort — NOT for the concert window.

- [ ] **3.1 Decide engine direction:** (a) harden the native SoundPool engine as the canonical Android
      path and retire SoLoud-for-metronome, OR (b) build a **Dart FFI → Oboe** engine mirroring Tack's
      10-call bridge (create/init/setTickData/playTick/start/stop/setMasterVolume/setDuckingVolume/
      setMuted/destroy), one shared native engine across platforms.
- [ ] **3.2 If FFI Oboe:** real-time callback, lock-free atomic tick handoff, voice pool + stealing,
      sample-accurate placement, disconnect recovery — per `architecture_for_redesign.md` §3.
- [ ] **3.3 Keep the layer boundary** (Dart decides / native renders); pre-decode sounds, trigger by
      index (cold/hot split).
- [ ] **3.4 Refactor debt:** keep scheduler / `MetronomeConfig` / persistence separate (avoid Tack's
      god-class). Our provider split is already close — tidy, don't monolith.
- [ ] **3.5 iOS path** (AVAudioEngine / miniaudio) if/when iOS ships, reusing the same bridge.

---

## Sequencing & risk

- **This week = Phase 0 only.** It is a config flip + on-device verification, reversible, no rewrite —
  the safe move before a live show. Do NOT start Phase 3 before the concert.
- Phases 1–2 are the real "inspired by Tack" hardening; Phase 3 is the optional quality ceiling.
- Every audio change is verified **on the physical concert device with real BT hardware** — none of this
  reproduces in a simulator/unit test.
