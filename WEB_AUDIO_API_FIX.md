# Web Audio API Fix: Oscillator Type Assignment

## Problem Summary

**Error Location:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/services/audio_engine.dart` (line 41)

**Error Message:**
```
oscillator.type = waveType.toJS;
// Error: JSString can't be assigned to String
```

## Root Cause Analysis

### The Issue

The code incorrectly uses `.toJS` when setting the oscillator type:

```dart
// WRONG - causes type error
oscillator.type = waveType.toJS;
```

### Why This Fails

1. **`package:web` uses `OscillatorType` typedef:**
   - `OscillatorType` is defined as `typedef OscillatorType = String;`
   - It expects a **Dart `String`**, NOT a `JSString`

2. **`.toJS` converts Dart String to JSString:**
   - `waveType.toJS` converts a Dart `String` to a `JSString`
   - This is the wrong type for `package:web` bindings

3. **`package:web` handles interop automatically:**
   - The `package:web` library uses zero-overhead bindings
   - It automatically handles Dart ↔ JavaScript type conversion
   - You should use regular Dart types, not JS interop types

## Correct Code Pattern

### The Fix

```dart
// CORRECT - use Dart String directly
oscillator.type = waveType;
```

### Complete Fixed Method

```dart
Future<void> playClick({
  required bool isAccent,
  required String waveType,
  required double volume,
}) async {
  if (!_initialized || _audioContext == null) {
    await initialize();
    if (!_initialized) return;
  }

  try {
    final oscillator = _audioContext!.createOscillator();
    final gainNode = _audioContext!.createGain();

    // Set wave type - use String directly, NOT .toJS
    oscillator.type = waveType;  // ✅ CORRECT

    // Frequency: accented beat = higher pitch (Reaper style)
    oscillator.frequency.value = isAccent ? 2000 : 1200;

    // Volume envelope to avoid clicking
    final now = _audioContext!.currentTime;
    gainNode.gain.setValueAtTime(0, now);
    gainNode.gain.linearRampToValueAtTime(volume, now + 0.001);
    gainNode.gain.exponentialRampToValueAtTime(0.001, now + 0.04);

    // Connect nodes
    oscillator.connect(gainNode);
    gainNode.connect(_audioContext!.destination);

    // Play short click (40ms like Reaper)
    oscillator.start(now);
    oscillator.stop(now + 0.04);
  } catch (e) {
    print('Error playing click: $e');
  }
}
```

## Type Conversion Reference

### When Using `package:web`

| Scenario | Correct Approach | Incorrect Approach |
|----------|-----------------|-------------------|
| Setting oscillator.type | `oscillator.type = waveType;` | `oscillator.type = waveType.toJS;` |
| Reading oscillator.type | `String type = oscillator.type;` | `JSString type = oscillator.type;` |
| Setting frequency | `oscillator.frequency.value = 440;` | `oscillator.frequency.value = 440.toJS;` |

### When Using Raw `dart:js_interop`

If you were using raw `dart:js_interop` without `package:web`, the pattern would be different:

```dart
import 'dart:js_interop';

// Dart String → JSString
String dartString = "sine";
JSString jsString = dartString.toJS;

// JSString → Dart String
JSString jsString = ...;
String dartString = jsString.toDart;
```

**But with `package:web`, you don't need this!** The package handles it automatically.

## Valid Oscillator Types

The `OscillatorType` typedef accepts these string values:

| Value | Description |
|-------|-------------|
| `'sine'` | Sine wave (default) |
| `'square'` | Square wave with 50% duty cycle |
| `'sawtooth'` | Sawtooth wave |
| `'triangle'` | Triangle wave |
| `'custom'` | Custom waveform (set via `setPeriodicWave()`) |

**Note:** Setting `type` to `'custom'` manually throws an `InvalidStateError`. Use `setPeriodicWave()` for custom waveforms.

## Working Example

### Complete Audio Engine Example

```dart
import 'package:web/web.dart' as web;

class AudioEngine {
  web.AudioContext? _audioContext;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _audioContext = web.AudioContext();
    _initialized = true;
  }

  Future<void> playTone({
    required String waveType,  // 'sine', 'square', 'sawtooth', 'triangle'
    required double frequency,
    required double volume,
    required double duration,
  }) async {
    if (!_initialized) await initialize();

    final oscillator = _audioContext!.createOscillator();
    final gainNode = _audioContext!.createGain();

    // ✅ Correct: Use String directly
    oscillator.type = waveType;
    oscillator.frequency.value = frequency;

    // Volume envelope
    final now = _audioContext!.currentTime;
    gainNode.gain.setValueAtTime(0, now);
    gainNode.gain.linearRampToValueAtTime(volume, now + 0.01);
    gainNode.gain.exponentialRampToValueAtTime(0.001, now + duration);

    // Connect and play
    oscillator.connect(gainNode);
    gainNode.connect(_audioContext!.destination);
    oscillator.start(now);
    oscillator.stop(now + duration);
  }
}
```

## Alternative Approaches

### Option 1: Using OscillatorType Explicitly

```dart
import 'package:web/web.dart' show OscillatorType;

void playSound() {
  final oscillator = _audioContext!.createOscillator();
  
  // Explicitly typed (optional, for clarity)
  OscillatorType type = 'sine';
  oscillator.type = type;
}
```

### Option 2: Using Enum for Type Safety

```dart
enum WaveType { sine, square, sawtooth, triangle }

extension WaveTypeExtension on WaveType {
  String get value => name;
}

void playSound() {
  final oscillator = _audioContext!.createOscillator();
  
  // Convert enum to string
  oscillator.type = WaveType.sine.value;
}
```

## Key Takeaways

1. **`package:web` = Dart types:** When using `package:web`, use regular Dart types (`String`, `int`, `double`), not JS interop types (`JSString`, `JSNumber`).

2. **No `.toJS` needed:** The package handles JavaScript interop automatically through zero-overhead bindings.

3. **`.toJS` is for raw interop:** Only use `.toJS` and `.toDart` when working directly with `dart:js_interop` without `package:web`.

4. **`OscillatorType = String`:** This typedef is just a semantic alias for `String` - treat it as a regular string.

## Files to Update

- `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/services/audio_engine.dart`
  - Line 41: Change `oscillator.type = waveType.toJS;` to `oscillator.type = waveType;`

## References

- [MDN: OscillatorNode.type](https://developer.mozilla.org/en-US/docs/Web/API/OscillatorNode/type)
- [package:web: OscillatorType](https://pub.dev/documentation/web/latest/web/OscillatorType.html)
- [package:web: OscillatorNode](https://pub.dev/documentation/web/latest/web/OscillatorNode-extension-type.html)
- [dart:js_interop: JSStringToString](https://api.flutter.dev/flutter/dart-js_interop/JSStringToString.html)
- [Dart Web Libraries Documentation](https://dart.cn/web/libraries)
