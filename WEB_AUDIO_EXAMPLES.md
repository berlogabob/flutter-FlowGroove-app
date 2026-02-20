# Flutter Web + Web Audio API Examples

A comprehensive guide to using Web Audio API with Flutter Web, including working examples, common patterns, and pitfalls to avoid.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Working Examples & Repositories](#working-examples--repositories)
3. [Package Options](#package-options)
4. [Core Concepts](#core-concepts)
5. [Code Examples](#code-examples)
6. [Common Patterns](#common-patterns)
7. [Pitfalls to Avoid](#pitfalls-to-avoid)
8. [Browser Compatibility](#browser-compatibility)
9. [Resources & Documentation](#resources--documentation)

---

## Quick Start

### Using `package:web` (Recommended for Flutter Web)

```yaml
# pubspec.yaml
dependencies:
  web: ^1.1.1
```

```dart
import 'package:web/web.dart';

void main() {
  final audioContext = AudioContext();
  final oscillator = audioContext.createOscillator();
  
  oscillator.type = OscillatorType.sine;
  oscillator.frequency.value = 440.0;
  oscillator.connect(audioContext.destination);
  oscillator.start();
  oscillator.stop(audioContext.currentTime + 1.0);
}
```

---

## Working Examples & Repositories

### GitHub Repositories

| Repository | Description | Language |
|------------|-------------|----------|
| [mfuentesg/metronome](https://github.com/mfuentesg/metronome) | Offline-first PWA metronome using AudioContext | TypeScript |
| [Tyrone2333/metronomelutter](https://github.com/Tyrone2333/metronomelutter) | Flutter metronome with Web support | Dart |
| [Isaac-To/flutter-metronome](https://github.com/Isaac-To/flutter-metronome) | Flutter metronome application | Dart |
| [Canardoux/etau](https://github.com/Canardoux/etau) | Web Audio API interface for Flutter (Alpha) | Dart |
| [AlvaroVasconcelos/flutter_web_audio_player](https://github.com/AlvaroVasconcelos/flutter_web_audio_player) | HTML5 audio playback for Flutter Web | Dart |

### Code Examples & Gists

| Resource | Description |
|----------|-------------|
| [Web Audio Example Gist](https://gist.github.com/thebeebs/ebbfb5e726e7c5392df994f98e3724a8) | Basic AudioContext and oscillator example |
| [MDN webaudio-examples](https://github.com/mdn/webaudio-examples) | Official Mozilla Web Audio API examples |
| [WebAudio-PulseOscillator](https://github.com/pendragon-andyh/WebAudio-PulseOscillator) | Custom pulse oscillator implementation |

### Live Demos

| Demo | Description |
|------|-------------|
| [CodePen: Web Audio Oscillator](https://codepen.io/jonoliver/pen/NoawPv) | Interactive oscillator demo |
| [Metronome by mfuentesg](https://mfuentesg.dev/metronome) | Production PWA metronome |

---

## Package Options

### 1. `package:web` (Official, Recommended)

**Pub.dev:** [web](https://pub.dev/packages/web)

Lightweight browser API bindings built around JS interop. Generated from Web IDL definitions.

```yaml
dependencies:
  web: ^1.1.1
```

```dart
import 'package:web/web.dart';

void playTone(double frequency, double duration) {
  final audioContext = AudioContext();
  final oscillator = audioContext.createOscillator();
  final gainNode = audioContext.createGain();
  
  oscillator.type = OscillatorType.sine;
  oscillator.frequency.value = frequency;
  gainNode.gain.value = 0.5;
  
  oscillator.connect(gainNode);
  gainNode.connect(audioContext.destination);
  
  oscillator.start();
  oscillator.stop(audioContext.currentTime + duration);
}
```

### 2. `package:metronome` (Specialized)

**Pub.dev:** [metronome](https://pub.dev/packages/metronome)

Cross-platform metronome package with Web Audio API support.

```yaml
dependencies:
  metronome: ^2.0.7
```

```dart
final metronome = Metronome();
await metronome.init(
  'assets/audio/snare.wav',
  accentedPath: 'assets/audio/claves.wav',
  bpm: 120,
  volume: 50,
  timeSignature: 4,
);
metronome.play();
```

### 3. `package:taudio_waa` (Mobile + Web)

**Pub.dev:** [taudio_waa](https://pub.dev/packages/taudio_waa)

Web Audio API port for Flutter Mobile and Desktop.

```yaml
dependencies:
  taudio_waa: ^0.0.2-beta-1+6
```

```dart
import 'package:taudio_waa/public/web_audio.dart';

final audioContext = AudioContext();
final oscillator = audioContext.createOscillator();
oscillator.type = 'sine';
oscillator.frequency.value = 440.0;
oscillator.connect(audioContext.destination);
oscillator.start();
```

### 4. `package:wajuce` (High Performance)

**Pub.dev:** [wajuce](https://pub.dev/packages/wajuce)

JUCE-powered Web Audio API implementation for Flutter.

```yaml
dependencies:
  wajuce: ^1.0.0
```

```dart
import 'package:wajuce/wajuce.dart';

final ctx = WAContext(sampleRate: 44100, bufferSize: 512);
await ctx.resume();

final oscillator = ctx.createOscillator();
oscillator.type = WAOscillatorType.sine;
oscillator.frequency.value = 440.0;
oscillator.start();
```

---

## Core Concepts

### Audio Context

The `AudioContext` is the entry point to the Web Audio API:

```dart
import 'package:web/web.dart';

final audioContext = AudioContext();

// Handle autoplay policy (required by browsers)
if (audioContext.state == 'suspended') {
  await audioContext.resume();
}
```

### Oscillator Types

| Type | Value | Sound Characteristic |
|------|-------|---------------------|
| Sine | `OscillatorType.sine` | Pure, smooth tone |
| Square | `OscillatorType.square` | Harsh, buzzy (retro games) |
| Sawtooth | `OscillatorType.sawtooth` | Bright, edgy |
| Triangle | `OscillatorType.triangle` | Soft, mellow |

```dart
oscillator.type = OscillatorType.sine;      // Default
oscillator.type = OscillatorType.square;
oscillator.type = OscillatorType.sawtooth;
oscillator.type = OscillatorType.triangle;
```

### Audio Nodes & Connections

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│ Oscillator  │ →  │    Gain      │ →  │ Destination │
│   (Source)  │    │  (Volume)    │    │ (Speakers)  │
└─────────────┘    └──────────────┘    └─────────────┘
```

```dart
final oscillator = audioContext.createOscillator();
final gainNode = audioContext.createGain();

oscillator.connect(gainNode);
gainNode.connect(audioContext.destination);
```

### AudioParam

Parameters like `frequency`, `gain`, and `pan` are `AudioParam` objects:

```dart
// Direct value setting
oscillator.frequency.value = 440.0;
gainNode.gain.value = 0.5;

// Scheduled changes
oscillator.frequency.setValueAtTime(440, audioContext.currentTime);
oscillator.frequency.linearRampToValueAtTime(880, audioContext.currentTime + 1);
oscillator.frequency.exponentialRampToValueAtTime(440, audioContext.currentTime + 2);

// Smooth transitions
oscillator.frequency.setTargetAtTime(440, audioContext.currentTime, 0.02);
```

---

## Code Examples

### 1. Basic Tone Generator

```dart
import 'package:web/web.dart';

void playTone() {
  final audioContext = AudioContext();
  final oscillator = audioContext.createOscillator();
  
  oscillator.type = OscillatorType.sine;
  oscillator.frequency.value = 440.0; // A4 note
  oscillator.connect(audioContext.destination);
  
  oscillator.start();
  oscillator.stop(audioContext.currentTime + 1.0);
}
```

### 2. Metronome Click with Envelope

```dart
import 'package:web/web.dart';

void playMetronomeClick(AudioContext audioContext, bool isAccent) {
  final oscillator = audioContext.createOscillator();
  final gainNode = audioContext.createGain();
  
  // Different pitch for accented beat (downbeat)
  oscillator.frequency.value = isAccent ? 1000.0 : 800.0;
  oscillator.type = OscillatorType.square;
  
  // Short click with exponential decay
  gainNode.gain.setValueAtTime(1.0, audioContext.currentTime);
  gainNode.gain.exponentialRampToValueAtTime(0.001, audioContext.currentTime + 0.05);
  
  oscillator.connect(gainNode);
  gainNode.connect(audioContext.destination);
  
  oscillator.start(audioContext.currentTime);
  oscillator.stop(audioContext.currentTime + 0.05);
}
```

### 3. ADSR Envelope

```dart
import 'package:web/web.dart';

void playNoteWithADSR(AudioContext audioContext, double frequency) {
  final oscillator = audioContext.createOscillator();
  final gainNode = audioContext.createGain();
  
  oscillator.type = OscillatorType.sine;
  oscillator.frequency.value = frequency;
  
  final now = audioContext.currentTime;
  
  // ADSR Envelope
  final attackTime = 0.01;
  final decayTime = 0.2;
  final sustainLevel = 0.7;
  final releaseTime = 0.3;
  final noteDuration = 1.0;
  
  // Attack: ramp to peak
  gainNode.gain.setValueAtTime(0.0, now);
  gainNode.gain.linearRampToValueAtTime(1.0, now + attackTime);
  
  // Decay: ramp to sustain level
  gainNode.gain.exponentialRampToValueAtTime(
    sustainLevel,
    now + attackTime + decayTime,
  );
  
  // Hold at sustain level
  gainNode.gain.setValueAtTime(sustainLevel, now + noteDuration);
  
  // Release: fade out
  gainNode.gain.exponentialRampToValueAtTime(
    0.001,
    now + noteDuration + releaseTime,
  );
  
  oscillator.connect(gainNode);
  gainNode.connect(audioContext.destination);
  
  oscillator.start(now);
  oscillator.stop(now + noteDuration + releaseTime);
}
```

### 4. Multiple Oscillators (Chord)

```dart
import 'package:web/web.dart';

void playChord(AudioContext audioContext, List<double> frequencies) {
  for (final freq in frequencies) {
    final oscillator = audioContext.createOscillator();
    final gainNode = audioContext.createGain();
    
    oscillator.type = OscillatorType.sine;
    oscillator.frequency.value = freq;
    gainNode.gain.value = 0.2; // Lower volume per oscillator
    
    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);
    
    oscillator.start(audioContext.currentTime);
    oscillator.stop(audioContext.currentTime + 2.0);
  }
}

// C Major chord
playChord(audioContext, [261.63, 329.63, 392.00]);
```

### 5. Stereo Panning

```dart
import 'package:web/web.dart';

void playWithPanning(AudioContext audioContext, double panValue) {
  final oscillator = audioContext.createOscillator();
  final gainNode = audioContext.createGain();
  final panner = StereoPannerNode(audioContext, StereoPannerOptions(pan: panValue));
  
  oscillator.type = OscillatorType.sine;
  oscillator.frequency.value = 440.0;
  gainNode.gain.value = 0.5;
  
  oscillator.connect(gainNode);
  gainNode.connect(panner);
  panner.connect(audioContext.destination);
  
  oscillator.start();
  oscillator.stop(audioContext.currentTime + 1.0);
}

// Pan values: -1 (left), 0 (center), 1 (right)
```

### 6. Complete Metronome Class

```dart
import 'package:web/web.dart';

class Metronome {
  AudioContext? _audioContext;
  bool _isPlaying = false;
  int _bpm = 120;
  int _beatsPerMeasure = 4;
  int _currentBeat = 0;
  double _nextNoteTime = 0;
  
  // Lookahead scheduling
  static const double _scheduleAheadTime = 0.1; // seconds
  static const double _lookahead = 25.0; // milliseconds
  
  Timer? _timer;
  
  Future<void> start() async {
    if (_isPlaying) return;
    
    _audioContext = AudioContext();
    await _audioContext!.resume();
    
    _isPlaying = true;
    _currentBeat = 0;
    _nextNoteTime = _audioContext!.currentTime;
    
    _scheduleAhead();
  }
  
  void _scheduleAhead() {
    if (!_isPlaying) return;
    
    while (_nextNoteTime < _audioContext!.currentTime + _scheduleAheadTime) {
      _scheduleNote(_currentBeat, _nextNoteTime);
      _nextNote();
    }
    
    _timer = Timer(Duration(milliseconds: _lookahead.toInt()), _scheduleAhead);
  }
  
  void _nextNote() {
    final secondsPerBeat = 60.0 / _bpm;
    _nextNoteTime += secondsPerBeat;
    _currentBeat++;
    if (_currentBeat >= _beatsPerMeasure) {
      _currentBeat = 0;
    }
  }
  
  void _scheduleNote(int beatNumber, double time) {
    final oscillator = _audioContext!.createOscillator();
    final gainNode = _audioContext!.createGain();
    
    // Accented beat (downbeat) has higher pitch
    oscillator.frequency.value = beatNumber == 0 ? 1000.0 : 800.0;
    oscillator.type = OscillatorType.square;
    
    // Short click with envelope
    gainNode.gain.setValueAtTime(1.0, time);
    gainNode.gain.exponentialRampToValueAtTime(0.001, time + 0.05);
    
    oscillator.connect(gainNode);
    gainNode.connect(_audioContext!.destination);
    
    oscillator.start(time);
    oscillator.stop(time + 0.05);
  }
  
  void stop() {
    _isPlaying = false;
    _timer?.cancel();
    _audioContext?.close();
  }
  
  void setBpm(int bpm) {
    _bpm = bpm.clamp(20, 300);
  }
  
  void setBeatsPerMeasure(int beats) {
    _beatsPerMeasure = beats.clamp(1, 12);
  }
}
```

### 7. Flutter Widget Integration

```dart
import 'package:flutter/material.dart';
import 'package:web/web.dart';

class AudioSynthWidget extends StatefulWidget {
  @override
  State<AudioSynthWidget> createState() => _AudioSynthWidgetState();
}

class _AudioSynthWidgetState extends State<AudioSynthWidget> {
  AudioContext? _audioContext;
  OscillatorNode? _oscillator;
  GainNode? _gainNode;
  double _frequency = 440.0;
  double _volume = 0.5;
  OscillatorType _type = OscillatorType.sine;
  
  @override
  void initState() {
    super.initState();
    _initAudioContext();
  }
  
  Future<void> _initAudioContext() async {
    _audioContext = AudioContext();
    await _audioContext!.resume();
  }
  
  void _startOscillator() {
    _oscillator = _audioContext!.createOscillator();
    _gainNode = _audioContext!.createGain();
    
    _oscillator!.type = _type;
    _oscillator!.frequency.value = _frequency;
    _gainNode!.gain.value = _volume;
    
    _oscillator!.connect(_gainNode!);
    _gainNode!.connect(_audioContext!.destination);
    
    _oscillator!.start();
  }
  
  void _stopOscillator() {
    _oscillator?.stop();
    _oscillator = null;
    _gainNode = null;
  }
  
  void _updateFrequency(double value) {
    setState(() => _frequency = value);
    _oscillator?.frequency.setTargetAtTime(
      value,
      _audioContext!.currentTime,
      0.02,
    );
  }
  
  @override
  void dispose() {
    _stopOscillator();
    _audioContext?.close();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          value: _frequency,
          min: 100,
          max: 2000,
          onChanged: _updateFrequency,
        ),
        Text('Frequency: ${_frequency.toStringAsFixed(0)} Hz'),
        ElevatedButton(
          onPressed: _oscillator == null ? _startOscillator : _stopOscillator,
          child: Text(_oscillator == null ? 'Play' : 'Stop'),
        ),
      ],
    );
  }
}
```

---

## Common Patterns

### 1. Audio Context Singleton

```dart
class AudioEngine {
  static AudioContext? _context;
  
  static Future<AudioContext> get context async {
    _context ??= AudioContext();
    await _context!.resume();
    return _context!;
  }
  
  static Future<void> close() async {
    await _context?.close();
    _context = null;
  }
}
```

### 2. User Gesture Handling (Autoplay Policy)

```dart
// Browsers require user interaction before audio can play
class AudioButton extends StatelessWidget {
  final AudioContext audioContext;
  
  Future<void> _handleTap() async {
    // Resume context on user gesture
    if (audioContext.state == 'suspended') {
      await audioContext.resume();
    }
    // Now safe to play audio
    playSound();
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Text('Play Sound'),
    );
  }
}
```

### 3. Node Cleanup Pattern

```dart
class SoundPlayer {
  final AudioContext audioContext;
  OscillatorNode? _oscillator;
  GainNode? _gain;
  
  void play() {
    _oscillator = audioContext.createOscillator();
    _gain = audioContext.createGain();
    
    _oscillator!.connect(_gain!);
    _gain!.connect(audioContext.destination);
    _oscillator!.start();
  }
  
  void stop() {
    _oscillator?.stop();
    _oscillator?.disconnect();
    _gain?.disconnect();
    _oscillator = null;
    _gain = null;
  }
  
  void dispose() {
    stop();
  }
}
```

### 4. Smooth Parameter Transitions

```dart
// Avoid clicking by using smooth transitions
void glideToFrequency(double targetFreq) {
  _oscillator?.frequency.setTargetAtTime(
    targetFreq,
    _audioContext.currentTime,
    0.02, // Time constant (smaller = faster)
  );
}

void fadeVolume(double targetVolume) {
  _gainNode?.gain.setTargetAtTime(
    targetVolume,
    _audioContext.currentTime,
    0.05,
  );
}
```

### 5. Precise Timing with AudioContext.currentTime

```dart
// Schedule events precisely using audio clock (not wall clock)
void scheduleNote(double when, double frequency) {
  final oscillator = audioContext.createOscillator();
  final gain = audioContext.createGain();
  
  oscillator.frequency.setValueAtTime(frequency, when);
  gain.gain.setValueAtTime(1.0, when);
  gain.gain.exponentialRampToValueAtTime(0.001, when + 0.1);
  
  oscillator.connect(gain);
  gain.connect(audioContext.destination);
  
  oscillator.start(when);
  oscillator.stop(when + 0.1);
}

// Schedule multiple notes
final now = audioContext.currentTime;
scheduleNote(now, 440);
scheduleNote(now + 0.5, 554);
scheduleNote(now + 1.0, 659);
```

---

## Pitfalls to Avoid

### 1. JSString Type Conversion Errors

**Problem:** Setting oscillator type with wrong type causes `JSString` conversion errors.

```dart
// WRONG - causes type error
oscillator.type = 'sine' as JSString;

// CORRECT - use enum or proper string
oscillator.type = OscillatorType.sine;
// OR
oscillator.type = 'sine'; // package:web handles conversion
```

### 2. AudioContext Not Resumed

**Problem:** Audio doesn't play due to browser autoplay policy.

```dart
// WRONG - context starts suspended
final audioContext = AudioContext();
oscillator.start(); // May not play!

// CORRECT - resume on user gesture
final audioContext = AudioContext();
await audioContext.resume(); // Call after user interaction
oscillator.start();
```

### 3. Reusing Oscillators

**Problem:** Oscillators can only be started once.

```dart
// WRONG - will throw error on second start
oscillator.start();
oscillator.stop();
oscillator.start(); // ERROR!

// CORRECT - create new oscillator each time
void playNote() {
  final oscillator = audioContext.createOscillator();
  oscillator.start();
  oscillator.stop(audioContext.currentTime + 0.1);
}
```

### 4. Missing Node Disconnection

**Problem:** Memory leaks from not disconnecting nodes.

```dart
// WRONG - nodes not cleaned up
void play() {
  final oscillator = audioContext.createOscillator();
  oscillator.start();
  // oscillator never stopped or disconnected
}

// CORRECT
void play() {
  final oscillator = audioContext.createOscillator();
  final gain = audioContext.createGain();
  
  oscillator.connect(gain);
  gain.connect(audioContext.destination);
  
  oscillator.start();
  oscillator.stop(audioContext.currentTime + 0.1);
  
  // Cleanup after sound finishes
  Future.delayed(Duration(milliseconds: 150), () {
    oscillator.disconnect();
    gain.disconnect();
  });
}
```

### 5. Using Wall Clock for Timing

**Problem:** JavaScript timers are imprecise for audio timing.

```dart
// WRONG - uses imprecise timers
Timer(Duration(milliseconds: 500), () {
  playNote(); // Timing drifts!
});

// CORRECT - use AudioContext.currentTime
final now = audioContext.currentTime;
oscillator.start(now);
oscillator.stop(now + 0.5); // Precise timing
```

### 6. Setting 'custom' Type Directly

**Problem:** Cannot set `type = 'custom'` directly.

```dart
// WRONG - throws InvalidStateError
oscillator.type = 'custom';

// CORRECT - use setPeriodicWave
final real = Float32List.fromList([1, 0.5, 0.25]);
final imag = Float32List.fromList([0, 0, 0]);
final wave = audioContext.createPeriodicWave(real, imag);
oscillator.setPeriodicWave(wave); // Automatically sets type to 'custom'
```

### 7. Not Handling AudioContext State

**Problem:** Not checking if context is running.

```dart
// WRONG
void play() {
  oscillator.start(); // May fail if context suspended
}

// CORRECT
Future<void> play() async {
  if (audioContext.state == 'suspended') {
    await audioContext.resume();
  }
  oscillator.start();
}
```

---

## Browser Compatibility

### Web Audio API Support

| Browser | Version | Notes |
|---------|---------|-------|
| Chrome | 10+ | Full support |
| Firefox | 25+ | Full support |
| Safari | 6+ | Full support |
| Edge | 12+ | Full support |
| Opera | 15+ | Full support |

### Flutter Web Considerations

| Feature | Support | Notes |
|---------|---------|-------|
| `package:web` | ✅ | Official, recommended |
| `dart:html` | ⚠️ | Deprecated, use `package:web` |
| `AudioContext` | ✅ | Full support via `package:web` |
| `OscillatorNode` | ✅ | All oscillator types supported |
| `GainNode` | ✅ | Full ADSR envelope support |
| `StereoPannerNode` | ✅ | Full stereo panning |
| `AnalyserNode` | ✅ | FFT visualization support |
| `AudioWorklet` | ⚠️ | Limited Dart support |
| `MediaStream` | ⚠️ | Requires additional permissions |

### Mobile Browser Notes

- **iOS Safari:** Requires user gesture to start audio (strict autoplay policy)
- **Android Chrome:** Similar autoplay restrictions
- **All mobile:** AudioContext may suspend when app goes to background

### Wasm Considerations

When compiling to WebAssembly (WasmGC):

```dart
// package:web works with both JS and Wasm targets
// No code changes needed for Wasm compilation
flutter build web --wasm
```

---

## Resources & Documentation

### Official Documentation

| Resource | URL |
|----------|-----|
| Dart Web Libraries | https://dart.dev/web/libraries |
| package:web | https://pub.dev/packages/web |
| package:web API | https://pub.dev/documentation/web/latest/ |
| JS Interop Guide | https://dart.dev/interop/js-interop |
| Migration Guide | https://dart.dev/interop/js-interop/package-web |
| MDN Web Audio API | https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API |
| OscillatorNode | https://developer.mozilla.org/en-US/docs/Web/API/OscillatorNode |
| AudioContext | https://developer.mozilla.org/en-US/docs/Web/API/AudioContext |

### Dart API References

| Class | Documentation |
|-------|---------------|
| OscillatorNode | https://api.dart.dev/dart-web_audio/OscillatorNode-class.html |
| AudioContext | https://api.dart.dev/dart-web_audio/AudioContext-class.html |
| GainNode | https://api.dart.dev/dart-web_audio/GainNode-class.html |
| JSString | https://api.flutter.dev/flutter/dart-js_interop/JSStringToString.html |

### Tutorials & Guides

| Resource | Description |
|----------|-------------|
| MDN: Using Web Audio API | https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Using_Web_Audio_API |
| MDN: Advanced Techniques | https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Advanced_techniques |
| Creating a Metronome | https://blog.paul.cx/post/metronome/ |
| Web Audio API Tutorial | https://www.toptal.com/developers/web/web-audio-api-tutorial |

### Stack Overflow Topics

| Topic | Common Questions |
|-------|-----------------|
| AudioContext not starting | Autoplay policy, user gesture required |
| OscillatorNode type errors | JSString conversion, use OscillatorType enum |
| Timing precision | Use AudioContext.currentTime, not timers |
| Memory leaks | Disconnect nodes, close context |

### GitHub Issues & Discussions

| Issue | Description |
|-------|-------------|
| [flutter_sound #496](https://github.com/AgoraIO/Agora-Flutter-SDK/issues/496) | AudioContext not allowed to start |
| [flutter_sound #963](https://github.com/Canardoux/flutter_sound/issues/963) | Using Web Audio API directly with Flutter Web |
| [dart-lang/web](https://github.com/dart-lang/web) | package:web issues and discussions |

---

## Quick Reference Card

```dart
// Import
import 'package:web/web.dart';

// Create context
final ctx = AudioContext();
await ctx.resume();

// Create oscillator
final osc = ctx.createOscillator();
osc.type = OscillatorType.sine;  // sine, square, sawtooth, triangle
osc.frequency.value = 440.0;     // Hz

// Create gain (volume)
final gain = ctx.createGain();
gain.gain.value = 0.5;           // 0.0 to 1.0+

// Connect nodes
osc.connect(gain);
gain.connect(ctx.destination);

// Play with timing
osc.start(ctx.currentTime);
osc.stop(ctx.currentTime + 1.0);

// Cleanup
osc.disconnect();
gain.disconnect();
await ctx.close();
```

---

*Last updated: February 2026*
