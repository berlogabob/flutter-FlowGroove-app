# Metronome Background Playback via Android Foreground Service

**Date:** 2026-06-22
**Status:** Approved design
**Scope:** Android only (iOS background audio is future work)

## Problem

When the metronome is playing and the user leaves the app — switches to another
app, turns off the screen, or receives a phone call — the beeping stops. Users
need the metronome to play **continuously** regardless of background state,
screen state, or interruptions (calls, notifications, app switches).

### Why it stops today

The live Android playback path is **Dart-driven**. With
`MetronomeFeatureFlags.enableUnifiedEngine = true`, playback runs through
`UnifiedEnginePlaybackClient → MetronomeScheduler → PcmClickRenderer →
flutter_soloud`, and the audio loop is pumped by a Dart timer inside the Flutter
isolate. Two mechanisms kill it in the background:

1. `MainActivity.onPause()` explicitly calls `metronomeEngine.stop()` when the
   activity leaves the foreground.
2. Even without (1), Android suspends/throttles the Dart isolate and its timers
   when the app is not foreground, so the scheduler stops feeding audio.

The reference app **tack-android** (`/Users/berloga/Documents/GitHub/tack/tack-android`)
solves this with a native **foreground service**
(`app/src/main/java/xyz/zedler/patrick/tack/service/MetronomeService.java`,
`foregroundServiceType="mediaPlayback"`) that owns the audio engine and runs
independently of the UI lifecycle. We adopt the same approach.

## Approach (chosen)

Run Android metronome playback inside a native **foreground service** of type
`mediaPlayback`. The OS does not suspend a foreground service, so the audio loop
keeps running through screen-off, app-switch, and calls.

We already have a working native engine, `AndroidMetronomeEngine` (SoundPool,
route-aware via `USAGE_MEDIA`, worker-thread timing), currently embedded in
`MainActivity` and bypassed by the unified engine. We move it into the service
and make the service the Android playback path.

**Rejected alternative:** keep the Dart unified engine and add
`flutter_foreground_task` to keep the isolate alive. Rejected because
flutter_soloud + Dart timers in the background are throttle-prone and surviving
call interruptions is not reliable — not tack-grade.

## Architecture

```
Dart                                  Android (native)
MetronomeNotifier
  → PlatformMetronomePlaybackClient
      --MethodChannel("com.flowgroove/metronome")-->
        MainActivity ──(bind/start)──► MetronomeForegroundService
                                          ├ AndroidMetronomeEngine (worker thread, SoundPool)
                                          └ persistent notification (Stop action)
      <--"tick"/"stopped" callbacks (UI sync; effective only in foreground)--
```

- The service is the **single owner** of `AndroidMetronomeEngine`. Playback runs
  there in both foreground and background — there is no hand-off at the
  background boundary, which avoids timing glitches and dropped beats when
  crossing it.
- On Android, `metronomePlaybackClientProvider` returns the native
  `PlatformMetronomePlaybackClient`. iOS and web keep
  `UnifiedEnginePlaybackClient` / `FlutterMetronomePlaybackClient` respectively.
  This is gated by a platform check; the unified engine is untouched off-Android.
- The three-pitch feature (primary / subdivision / accent-cyan) is preserved
  automatically: `MetronomePlaybackConfig.tickForIndex()` resolves each tick's
  frequency via `resolveClickFrequency()` and `toPlatformMap()` ships the
  resolved per-tick frequency to native. No native pitch logic changes needed.

## Components

### `MetronomeForegroundService` (new, Kotlin)
- `extends Service`, started with `startForeground(NOTIFICATION_ID, notification,
  FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)`.
- Hosts a single `AndroidMetronomeEngine` instance.
- Exposes a bound `Binder` so `MainActivity` can pass config and receive nothing
  back directly (tick callbacks flow through the existing MethodChannel held by
  the Flutter engine).
- Commands: `startPlayback(config)`, `updatePlayback(config)`, `stopPlayback()`.
- `stopPlayback()` (from Dart or the notification Stop action) stops the engine,
  calls `stopForeground(STOP_FOREGROUND_REMOVE)`, and `stopSelf()`.
- Builds/refreshes the notification with current BPM and a Stop action.

### `AndroidMetronomeEngine` (existing, moved)
- Moved from `MainActivity.kt` into the service (or a shared file the service
  owns). No behavioral change to its tick scheduling or sound generation.
- Continues to emit `"tick"` over the MethodChannel for UI sync. When the Flutter
  engine is detached (app backgrounded/killed), those callbacks are simply not
  delivered; playback is unaffected because timing lives in the engine, not Dart.

### `MainActivity` (modified)
- Keeps the `com.flowgroove/metronome` MethodChannel as the Dart entry point, but
  the handler now forwards to the service: `start`/`update` →
  `startForegroundService` + bind + `startPlayback`/`updatePlayback`; `stop` →
  `stopPlayback`.
- **Removes** the `onPause()` call that stops the metronome.
- On (re)bind, re-attaches the service so subsequent `"tick"` callbacks reach the
  current Flutter engine.
- `AudioRouteEmitter` (EventChannel `com.flowgroove/audio_route`) stays for the
  unified engine on other platforms; it is unused by the native Android path
  (the native engine follows the system route automatically) and is left intact.

### Dart `metronomePlaybackClientProvider` (modified)
- Add an Android branch that returns the native `PlatformMetronomePlaybackClient`
  instead of `UnifiedEnginePlaybackClient`, gated so non-Android platforms are
  unchanged.

## Calls / audio focus

The service plays on `USAGE_MEDIA` and **does not request-and-abandon audio focus
in a way that pauses playback**. On audio-focus loss (incoming call, another
media app) it **does not pause or duck** — it keeps beeping, per the product
requirement ("nevermind to incoming call"). The Dart `enableAudioFocus` flag has
no effect on the native service path.

## Notification

A foreground service requires an ongoing notification.

- Channel: low-importance, no sound/vibration of its own (the metronome is the
  sound).
- Content: title "Metronome", text "{bpm} BPM" (refreshed on `update`).
- One action: **Stop** (PendingIntent → service stops playback).
- Tap the notification body → reopens `MainActivity`.
- Android 13+ (`TIRAMISU`): request `POST_NOTIFICATIONS` at an appropriate time.
  If denied, the service still runs; the notification is simply not shown.

## Manifest / permissions

Add to `android/app/src/main/AndroidManifest.xml`:

- `<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />`
- `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />`
- `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />`
- `<service android:name=".MetronomeForegroundService"
    android:foregroundServiceType="mediaPlayback" android:exported="false" />`

## Error handling / edge cases

- **Notification permission denied** → service runs without a visible
  notification; no crash. (On some OEM/Android-15 configurations a media-playback
  foreground service may be throttled without a visible notification; acceptable
  for this round, revisit if devices show issues.)
- **Service start race** (rapid start/stop) → engine `stop()` is idempotent;
  `startPlayback` always re-initializes from the latest config.
- **Activity destroyed while playing** → service + engine survive; on relaunch,
  MainActivity re-binds. Tick UI re-syncs from the engine's ongoing callbacks.
- **Config update while playing** (BPM/pattern/pitch change) → `updatePlayback`
  re-arms the engine with the new tick list and refreshes the notification text.

## Testing

- Dart unit tests stay green: config mapping and tick-frequency resolution
  (`render_config_mapper_test`, `pcm_click_renderer_test`, `beat_mode_test`).
- Add a Dart test asserting `metronomePlaybackClientProvider` selects the native
  `PlatformMetronomePlaybackClient` on Android (and unified off-Android).
- Native engine timing is not unit-testable in this repo (no instrumentation
  harness); verify on-device manually:
  1. Start metronome → switch to another app → beep continues.
  2. Start metronome → turn screen off → beep continues.
  3. Start metronome → receive a call → beep continues during and after.
  4. Notification Stop → playback stops, notification clears.
  5. Change BPM/pattern while playing → audible change, notification updates.

## Out of scope (this round)

- iOS background audio (requires `AVAudioSession` `.playback` category + Background
  Modes capability + keeping flutter_soloud alive; separate spec).
- Play/pause from the notification (Stop only this round).
- Lock-screen media transport controls / MediaSession (tack uses one; we can add
  later if desired).
