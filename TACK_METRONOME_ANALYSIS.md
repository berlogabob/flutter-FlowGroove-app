# Tack Metronome Analysis

## Overview

Tack is a modern Android metronome app that uses **native C++ audio (Oboe)** for ultra-low-latency playback with a Java/Kotlin frontend. The implementation is sophisticated but can be simplified for Flutter.

---

## Timing Implementation

### Architecture
The app uses a **multi-threaded Handler-based timing system**:

```java
// Multiple HandlerThreads for separation of concerns
private HandlerThread tickThread, audioThread, callbackThread;
private Handler tickHandler, latencyHandler, audioHandler;
private Handler countInHandler, incrementalHandler, elapsedHandler, timerHandler, muteHandler;
```

### Core Timing Logic

**BPM to Interval Conversion:**
```java
public long getInterval() {
    return 1000 * 60 / Math.max(config.getTempo(), 1);  // 60000 / BPM = ms per beat
}
```

**Main Tick Scheduling:**
```java
private void startTicks() {
    long now = System.currentTimeMillis();
    nextScheduleTime = now;

    Runnable tickRunnable = new Runnable() {
        @Override
        public void run() {
            if (!isPlaying()) return;

            // Calculate beat/subdivision indices
            long beatIndex = config.usePolyrhythm()
                ? tickIndex
                : tickIndex / config.getSubdivisionsCount();
            boolean isBeat = config.usePolyrhythm()
                || (tickIndex % config.getSubdivisionsCount()) == 0;
            boolean isFirstBeat = isBeat && (beatIndex % config.getBeatsCount()) == 0;

            // Schedule next tick
            long interval = config.usePolyrhythm()
                ? getInterval()
                : getInterval() / config.getSubdivisionsCount();
            nextScheduleTime += interval;
            long delay = Math.max(0, nextScheduleTime - System.currentTimeMillis());
            tickHandler.postDelayed(this, delay);

            // Play audio
            if (performTick(tick)) {
                audioEngine.playTick(tick);
                tickIndex++;
            }
        }
    };

    audioHandler.post(() -> {
        audioEngine.play();
        tickHandler.post(tickRunnable);
    });
}
```

### Key Timing Features
- **Latency compensation**: Configurable offset applied to callbacks
- **Subdivision support**: Interval divided by subdivision count
- **Polyrhythm support**: Independent timing for polyrhythms
- **Drift correction**: Uses `System.currentTimeMillis()` to calculate actual delay

---

## Audio Playback

### Architecture
Uses **Oboe (C++ native audio)** for ultra-low-latency playback:

```java
// Java side - AudioEngine.java
static {
    System.loadLibrary("oboe-audio-engine");
}

// Native methods
private native long nativeCreate();
private native void nativeDestroy(long handle);
private native boolean nativeInit(long handle);
private native boolean nativeStart(long handle);
private native boolean nativeStop(long handle);
private native void nativeSetTickData(long handle, int tickType, float[] data);
private native void nativePlayTick(long handle, int tickType);
private native void nativeSetMasterVolume(long handle, float volume);
private native void nativeSetMuted(long handle, boolean muted);
```

### C++ Audio Engine (Oboe)

**Stream Configuration:**
```cpp
oboe::AudioStreamBuilder builder;
builder.setDirection(oboe::Direction::Output)
    ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
    ->setSharingMode(oboe::SharingMode::Exclusive)
    ->setFormat(oboe::AudioFormat::Float)
    ->setChannelCount(1)
    ->setSampleRate(mSampleRate)
    ->setDataCallback(this)
    ->setUsage(oboe::Usage::Game)
    ->setContentType(oboe::ContentType::Sonification);
```

**Audio Callback (Real-time mixing):**
```cpp
oboe::DataCallbackResult onAudioReady(
    oboe::AudioStream *stream, void *audioData, int32_t numFrames) override {

    auto *outputBuffer = static_cast<float *>(audioData);

    // Load audio buffers atomically
    auto strong = std::atomic_load(&mTickStrongPtr);
    auto normal = std::atomic_load(&mTickNormalPtr);
    auto sub = std::atomic_load(&mTickSubPtr);

    for (int i = 0; i < numFrames; ++i) {
        float drySample = 0.0f;

        // Mix active voices
        for (int v = 0; v < kNumVoices; ++v) {
            auto &buf = sourceData[v];
            if (buf && mReadIndexLocal[v] < static_cast<int32_t>(buf->size())) {
                drySample += (*buf)[mReadIndexLocal[v]];
                ++mReadIndexLocal[v];
            }
        }

        // Apply gain and limiter
        float amplified = drySample * inputGain;
        outputBuffer[i] = amplified * sLimiterGain;
    }

    return oboe::DataCallbackResult::Continue;
}
```

### Sound Playback Flow

1. **Load WAV files** into float arrays:
```java
private float[] loadAudio(@RawRes int resId, Pitch pitch) {
    try (InputStream stream = context.getResources().openRawResource(resId)) {
        return adjustPitch(AudioUtil.readDataFromWavFloat(stream), pitch);
    }
}
```

2. **Pitch adjustment** for different tick types:
```java
private float[] adjustPitch(float[] originalData, Pitch pitch) {
    if (pitch == Pitch.HIGH) {
        // Double pitch: take every other sample
        float[] newData = new float[originalData.length / 2];
        for (int i = 0; i < newData.length; i++) {
            newData[i] = originalData[i * 2];
        }
        return newData;
    } else if (pitch == Pitch.LOW) {
        // Half pitch: duplicate samples
        float[] newData = new float[originalData.length * 2];
        for (int i = 0, j = 0; i < originalData.length; i++, j += 2) {
            newData[j] = originalData[i];
            newData[j + 1] = originalData[i];
        }
        return newData;
    }
    return originalData;
}
```

3. **Play tick** with type selection:
```java
public void playTick(Tick tick) {
    if (!playing || !isInitialized() || muted || tick.isMuted) return;

    int nativeTickType;
    switch (tick.type) {
        case TICK_TYPE.STRONG:
            nativeTickType = NATIVE_TICK_TYPE_STRONG;
            break;
        case TICK_TYPE.SUB:
            nativeTickType = NATIVE_TICK_TYPE_SUB;
            break;
        case TICK_TYPE.MUTED:
        case TICK_TYPE.BEAT_SUB_MUTED:
            return;  // silence
        default:
            nativeTickType = NATIVE_TICK_TYPE_NORMAL;
    }

    nativePlayTick(engineHandle, nativeTickType);
}
```

---

## BPM Calculation

### Formula
```
interval_ms = 60000 / BPM
```

### Implementation
```java
public long getInterval() {
    return 1000 * 60 / Math.max(config.getTempo(), 1);
}

// For subdivisions:
long subdivisionInterval = getInterval() / config.getSubdivisionsCount();
```

### Tempo Control
```java
public void setTempo(int tempo) {
    if (config.getTempo() != tempo) {
        config.setTempo(tempo);
        sharedPrefs.edit().putInt(PREF.TEMPO, tempo).apply();
    }
}

// Incremental tempo changes
private void changeTempo(int change) {
    int tempoOld = config.getTempo();
    int tempoNew = tempoOld + change;
    setTempo(tempoNew);
}
```

---

## Beat Accents

### Tick Types
```java
public static class Tick {
    public final long index;
    public final int beat, subdivision;
    @NonNull public final String type;  // STRONG, BEAT, SUB, MUTED, BEAT_SUB_MUTED
    public final boolean isMuted, isPoly;
}
```

### Tick Type Constants
```java
public static class TICK_TYPE {
    public static final String STRONG = "strong";      // Accented first beat
    public static final String NORMAL = "normal";      // Regular beat
    public static final String SUB = "sub";            // Subdivision
    public static final String BEAT_SUB = "beat_sub";  // Beat subdivision
    public static final String MUTED = "muted";        // Silent beat
    public static final String BEAT_SUB_MUTED = "beat_sub_muted";
}
```

### Determining Tick Type
```java
private String getCurrentTickType() {
    if (config.usePolyrhythm()) {
        String[] beats = config.getBeats();
        int beatIndex = (int) (tickIndex % beats.length);
        return beats[beatIndex];
    } else {
        int subdivisionsCount = config.getSubdivisionsCount();
        if ((tickIndex % subdivisionsCount) == 0) {
            // On the beat
            String[] beats = config.getBeats();
            return beats[(int) ((tickIndex / subdivisionsCount) % beats.length)];
        } else {
            // Subdivision
            String[] subdivisions = config.getSubdivisions();
            return subdivisions[(int) (tickIndex % subdivisionsCount)];
        }
    }
}
```

### Haptic Feedback by Type
```java
latencyHandler.postDelayed(() -> {
    if (!beatMode.equals(BEAT_MODE.SOUND) && !tick.isMuted) {
        switch (tick.type) {
            case TICK_TYPE.STRONG:
                hapticUtil.heavyClick(false);  // Strong accent
                break;
            case TICK_TYPE.SUB:
                hapticUtil.tick(false);  // Light subdivision
                break;
            case TICK_TYPE.MUTED:
            case TICK_TYPE.BEAT_SUB_MUTED:
                break;  // No vibration
            default:
                hapticUtil.click(false);  // Regular beat
        }
    }
}, latency);
```

### Sound Presets
Different sounds for different tick types:
```java
// Example: Mechanical sound preset
case SOUND.MECHANICAL:
    resIdNormal = R.raw.mechanical_tick;   // Regular beat
    resIdStrong = R.raw.mechanical_ding;   // Accented beat
    resIdSub = R.raw.mechanical_knock;     // Subdivision
    break;
```

---

## Key Code Snippets (Simplified)

### 1. Simple Timer-Based Metronome
```java
// Simple Handler-based timing
private Handler handler = new Handler();
private Runnable tickRunnable;
private long intervalMs;
private long nextTickTime;

public void start(int bpm) {
    intervalMs = 60000 / bpm;
    nextTickTime = System.currentTimeMillis();

    tickRunnable = new Runnable() {
        @Override
        public void run() {
            // Calculate drift correction
            long delay = Math.max(0, nextTickTime - System.currentTimeMillis());
            nextTickTime += intervalMs;

            // Play sound
            playBeat();

            // Schedule next
            handler.postDelayed(this, delay);
        }
    };

    handler.post(tickRunnable);
}

public void stop() {
    handler.removeCallbacks(tickRunnable);
}
```

### 2. Simple Sound Playback with SoundPool
```java
// For Flutter: Use audioplayers or just_audio package
SoundPool soundPool = new SoundPool.Builder()
    .setMaxStreams(4)
    .build();

int strongBeatId = soundPool.load(context, R.raw.strong, 1);
int normalBeatId = soundPool.load(context, R.raw.normal, 1);

public void playBeat(boolean isStrong) {
    int soundId = isStrong ? strongBeatId : normalBeatId;
    soundPool.play(soundId, 1.0f, 1.0f, 1, 0, 1.0f);
}
```

### 3. Start/Stop Logic
```java
private AtomicBoolean isPlaying = new AtomicBoolean(false);

public void start() {
    if (isPlaying.compareAndSet(false, true)) {
        audioEngine.play();
        startTicks();
        notifyListenersOnStart();
    }
}

public void stop() {
    if (isPlaying.compareAndSet(true, false)) {
        removeHandlerCallbacks();
        audioEngine.scheduleDelayedStop();
        notifyListenersOnStop();
    }
}
```

---

## Recommendations for Flutter

### Option 1: Simple Implementation (Recommended for MVP)

**Packages:**
- `audioplayers` or `just_audio` - Audio playback
- `Timer` from `dart:async` - Basic timing
- `vibration` - Haptic feedback

**Basic Structure:**
```dart
class MetronomeService {
  late AudioPlayer strongPlayer;
  late AudioPlayer normalPlayer;
  Timer? _timer;
  bool _isPlaying = false;
  int _bpm = 120;
  int _beatIndex = 0;

  Future<void> init() async {
    strongPlayer = AudioPlayer();
    normalPlayer = AudioPlayer();

    await strongPlayer.setSource(AssetSource('sounds/strong.wav'));
    await normalPlayer.setSource(AssetSource('sounds/normal.wav'));
  }

  void start(int bpm) {
    if (_isPlaying) return;
    _isPlaying = true;
    _bpm = bpm;
    _beatIndex = 0;

    final interval = Duration(milliseconds: (60000 / bpm).round());

    _timer = Timer.periodic(interval, (_) {
      _playBeat();
    });
  }

  void _playBeat() {
    bool isStrong = _beatIndex % 4 == 0;  // 4/4 time

    if (isStrong) {
      strongPlayer.resume();
      Vibration.vibrate(pattern: [0, 100]);  // Strong vibration
    } else {
      normalPlayer.resume();
      Vibration.vibrate(pattern: [0, 50]);   // Light vibration
    }

    _beatIndex++;
  }

  void stop() {
    _timer?.cancel();
    _isPlaying = false;
    _beatIndex = 0;
  }

  void setBpm(int bpm) {
    _bpm = bpm;
    if (_isPlaying) {
      stop();
      start(bpm);
    }
  }
}
```

### Option 2: Better Timing with Precise Scheduling

```dart
class PreciseMetronome {
  Timer? _timer;
  bool _isPlaying = false;
  int _bpm = 120;
  DateTime? _nextTickTime;

  void start(int bpm) {
    _isPlaying = true;
    _bpm = bpm;
    _nextTickTime = DateTime.now();

    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    if (!_isPlaying) return;

    final intervalMs = 60000 / _bpm;
    final now = DateTime.now();
    final delay = _nextTickTime!.difference(now);

    if (delay.inMilliseconds > 0) {
      Future.delayed(Duration(milliseconds: delay.inMilliseconds), () {
        _playBeat();
        _nextTickTime = _nextTickTime!.add(
          Duration(milliseconds: intervalMs.round())
        );
        _scheduleNextTick();
      });
    } else {
      // Catch up if we're behind
      _playBeat();
      _nextTickTime = DateTime.now().add(
        Duration(milliseconds: intervalMs.round())
      );
      _scheduleNextTick();
    }
  }

  void _playBeat() {
    // Play audio and haptic
  }
}
```

### Option 3: Advanced (Native Integration)

For production-quality low-latency audio:

1. **Use `flutter_sound`** - More control over audio
2. **Platform channels** - Call native Oboe/AAudio on Android
3. **Pre-load sounds** into memory for instant playback

### Audio Files Needed

Create simple WAV files:
- `strong.wav` - High-pitched click (accented beat)
- `normal.wav` - Medium click (regular beat)
- `sub.wav` - Low click (subdivision, optional)

### Key Considerations for Flutter

1. **Timer drift**: Use `DateTime` for drift correction, not just `Timer.periodic`
2. **Audio latency**: Pre-load sounds, use low-latency audio packages
3. **Background execution**: Use `flutter_background_service` for background playback
4. **Haptic feedback**: Use `vibration` package with patterns for accents
5. **State management**: Keep BPM and playing state in a provider/bloc

---

## File Reference

| File | Path | Purpose |
|------|------|---------|
| MetronomeEngine | `/app/src/main/java/xyz/zedler/patrick/tack/metronome/MetronomeEngine.java` | Core timing and beat logic |
| AudioEngine | `/app/src/main/java/xyz/zedler/patrick/tack/metronome/AudioEngine.java` | Java audio interface |
| Oboe Engine | `/app/src/main/cpp/oboe_audio_engine.cpp` | Native C++ low-latency audio |
| MetronomeService | `/app/src/main/java/xyz/zedler/patrick/tack/service/MetronomeService.java` | Android foreground service |
| MetronomeConfig | `/app/src/main/java/xyz/zedler/patrick/tack/model/MetronomeConfig.java` | Configuration storage |
| AudioUtil | `/app/src/main/java/xyz/zedler/patrick/tack/util/AudioUtil.java` | WAV file reading utilities |

---

## Summary

**Tack's approach:**
- **Timing**: Handler-based with drift correction
- **Audio**: Native Oboe (C++) for ultra-low latency
- **BPM Formula**: `interval_ms = 60000 / BPM`
- **Accents**: Three tick types (STRONG, NORMAL, SUB) with different sounds

**For Flutter MVP:**
- Use `audioplayers` + `Timer` with drift correction
- Pre-load 2-3 sound files
- Add haptic feedback for accents
- Implement simple start/stop/BPM control
