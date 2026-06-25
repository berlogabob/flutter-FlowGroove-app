# Metronome Web Audio — Issue Report

## Finding

On Flutter Web the metronome runs the UI/state correctly but produces **no sound**.
There is no runtime exception and no web-specific bug report visible from code paths.

## Root cause

**The active playback client on web bypasses the working Web Audio API adapter
and uses a `flutter_soloud` PCM stream path that is not reliable on web.**

Code path:

- `lib/config/metronome_feature_flags.dart:12` hardcodes
  `enablePcmTimelineEngine = true`.
- `lib/providers/metronome_runtime_providers.dart:825-830` then always picks
  `PcmTimelineMetronomePlaybackClient` as the active playback client on web,
  with legacy/fallback clients underneath but never reached on the failing path.
- `PcmTimelineMetronomePlaybackClient.start()` in
  `lib/providers/metronome_runtime_providers.dart:221-229` initializes
  `flutter_soloud`, creates a buffer stream, calls `_appendChunk()` twice,
  then starts playback.
- `_appendChunk()` at `lib/providers/metronome_runtime_providers.dart:330`
  calls `SoLoud.instance.addAudioDataStream(...)`.

On web, `flutter_soloud` is backed by Web Audio, but the PCM-streaming
integration used here is not the same path as the existing tested
`AudioEngineWeb` adapter and is more brittle on web. This mismatch is the
silent failure source.

Supporting evidence:

- `lib/services/audio/audio_engine_web.dart` defines a clean Web Audio API
  metronome engine (`AudioEngine`) that is wired through
  `AudioEngineMetronomeAudioClient` -> `MetronomeAudioEngine.instance`,
  but this adapter is not used by `PcmTimelineMetronomePlaybackClient`.
- `AudioEngineWeb.playClick()` is browser-safe and initializes the
  `AudioContext` after user interaction. It is bypassed on web today.

## Fix (recommended)

Choose one of the two approaches below.

### Option A — Use existing Web Audio path on web (low risk)

Keep the PCM timeline on mobile/native, but switch to the existing
`AudioEngine`/Web Audio adapter on web.

1. In `lib/providers/metronome_runtime_providers.dart`, select the playback
   client by platform:

```dart
final client = kIsWeb && MetronomeFeatureFlags.enablePcmTimelineEngine
    ? FlutterMetronomePlaybackClient(
        audioClient: ref.read(metronomeAudioClientProvider),
        hapticsClient: ref.read(metronomeHapticsProvider),
      )
    : PcmTimelineMetronomePlaybackClient(fallback: legacy);
```

2. Make `metronomeAudioClientProvider` return `AudioEngineMetronomeAudioClient`
   on web so clicks go through `lib/services/audio/audio_engine_web.dart`.

3. Verify `AudioEngineWeb.initialize()` is triggered from a user gesture
   (play button). It already does this on first `playClick`.

### Option B — Make PCM timeline safe on web (higher effort)

1. Make `_appendChunk()` in
   `lib/providers/metronome_runtime_providers.dart` null-safe and awaited,
   and do not start playback before the buffer is appended.
2. Add explicit web-compatible `flutter_soloud` init and check
   `SoLoud.instance.isInitialized` before `addAudioDataStream`.
3. Keep a fallback to legacy Flutter scheduler on web if PCM init fails.

## Verification steps

1. Build and run web build: `flutter run -d chrome --web-renderer canvaskit`
2. Open metronome, tap Play, adjust volume and wave type.
3. Confirm audible ticks on downbeat and subdivisions.
4. Switch wave type/volume and confirm changes take effect.
5. Run on mobile/desktop to confirm no regression.
