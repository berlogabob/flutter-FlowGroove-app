# Audio Engine Fix Plan

## Root Cause

The compilation error occurs at line 42 in `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/services/audio_engine.dart`:

```dart
oscillator.type = waveType.toJS;
// Error: A value of type 'JSString' can't be assigned to a variable of type 'String'
```

### Why This Error Occurs

1. **`OscillatorType` is a typedef for `String`, not `JSString`:**
   ```dart
   typedef OscillatorType = String;
   ```

2. **The `.toJS` extension method converts Dart `String` to `JSString`:**
   ```dart
   String dartString = "sine";
   JSString jsString = dartString.toJS;  // Converts to JSString
   ```

3. **`package:web` uses zero-overhead bindings:**
   - The `package:web` library automatically handles Dart ↔ JavaScript type conversion
   - You should use regular Dart types (`String`, `int`, `double`)
   - The `.toJS` conversion is only needed when using raw `dart:js_interop` without `package:web`

4. **Type mismatch:**
   - `oscillator.type` setter expects `OscillatorType` (which is `String`)
   - `waveType.toJS` produces `JSString`
   - `JSString` cannot be assigned to `String`

---

## Solution Options

### Option 1: Remove `.toJS` (Recommended)

Simply use the Dart `String` directly without any conversion:

```dart
// File: lib/services/audio_engine.dart
// Line 42 - Change from:
oscillator.type = waveType.toJS;

// To:
oscillator.type = waveType;
```

**Complete fixed method:**

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

**Pros:**
- Simplest fix (one-line change)
- Follows `package:web` best practices
- No additional dependencies or code changes
- Type-safe and clear

**Cons:**
- None

---

### Option 2: Use Explicit `OscillatorType` Typedef

Import and use the `OscillatorType` typedef explicitly for clarity:

```dart
import 'package:web/web.dart' show OscillatorType;

// In the playClick method:
OscillatorType type = waveType;  // Explicitly typed
oscillator.type = type;
```

**Pros:**
- Makes the expected type explicit in code
- Self-documenting

**Cons:**
- More verbose
- No functional benefit over Option 1
- Requires additional import

---

### Option 3: Use Enum for Type Safety

Create an enum for wave types to prevent invalid values at compile time:

```dart
enum WaveType {
  sine,
  square,
  triangle,
  sawtooth;

  String get value => name;
}

// In AudioEngine class:
Future<void> playClick({
  required bool isAccent,
  required WaveType waveType,  // Changed from String to enum
  required double volume,
}) async {
  // ...
  oscillator.type = waveType.value;  // Convert enum to String
  // ...
}
```

**Usage:**
```dart
await audioEngine.playClick(
  isAccent: true,
  waveType: WaveType.sine,  // Type-safe
  volume: 0.5,
);
```

**Pros:**
- Compile-time type safety
- Autocomplete support in IDEs
- Prevents invalid wave type strings

**Cons:**
- Requires changing the method signature
- Breaking change for existing callers
- More code changes required

---

## Recommended Fix

**Option 1: Remove `.toJS`** is the recommended fix.

### Implementation

**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/services/audio_engine.dart`

**Change at line 42:**

```diff
- oscillator.type = waveType.toJS;
+ oscillator.type = waveType;
```

### Complete Fixed File

```dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Audio engine for metronome sound synthesis
/// Uses Web Audio API for Flutter Web
class AudioEngine {
  web.AudioContext? _audioContext;
  bool _initialized = false;

  /// Initialize audio context (must be called after user interaction)
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _audioContext = web.AudioContext();
      _initialized = true;
      print('AudioContext initialized');
    } catch (e) {
      print('Failed to initialize AudioContext: $e');
    }
  }

  /// Play a click sound
  /// [isAccent] - true for accented beat (higher pitch)
  /// [waveType] - 'sine', 'square', 'triangle', or 'sawtooth'
  /// [volume] - 0.0 to 1.0
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
      oscillator.type = waveType;  // ✅ FIXED

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

  /// Play test sound to verify audio works
  Future<void> playTest() async {
    await playClick(isAccent: true, waveType: 'sine', volume: 0.5);
    await Future.delayed(const Duration(milliseconds: 200));
    await playClick(isAccent: false, waveType: 'sine', volume: 0.5);
  }

  /// Dispose audio resources
  void dispose() {
    _audioContext?.close();
    _initialized = false;
  }
}
```

---

## Testing Plan

### 1. Compile Verification

```bash
# Run Flutter analyzer to check for type errors
flutter analyze lib/services/audio_engine.dart

# Expected: No errors related to JSString/String type mismatch
```

### 2. Build Verification

```bash
# Build for web to ensure no compilation errors
flutter build web

# Expected: Build succeeds without errors
```

### 3. Runtime Verification

**Test in browser:**

1. Run the app:
   ```bash
   flutter run -d chrome
   ```

2. Navigate to the metronome feature

3. Test all wave types:
   - `'sine'` - should produce smooth tone
   - `'square'` - should produce buzzy tone
   - `'triangle'` - should produce soft tone
   - `'sawtooth'` - should produce harsh tone

4. Test accented vs. unaccented beats:
   - Accented beats should have higher pitch (2000 Hz)
   - Unaccented beats should have lower pitch (1200 Hz)

5. Test volume control:
   - Verify volume affects click loudness

### 4. Console Verification

Check browser console for errors:
- No `TypeError` related to oscillator type
- No `InvalidStateError` for wave type

Expected console output:
```
AudioContext initialized
```

### 5. Cross-Browser Testing

Test on multiple browsers to ensure compatibility:
- Chrome (Chromium)
- Firefox
- Safari (if on macOS)

**Expected behavior:** All browsers should produce identical audio output

---

## Fallback Options

### If Option 1 Fails

If removing `.toJS` causes runtime errors, try these fallbacks:

#### Fallback A: Explicit String Cast

```dart
oscillator.type = waveType as String;
```

#### Fallback B: Use OscillatorType Explicitly

```dart
import 'package:web/web.dart' show OscillatorType;

OscillatorType type = waveType;
oscillator.type = type;
```

#### Fallback C: Verify package:web Version

Check that you're using a compatible version of `package:web`:

```yaml
# pubspec.yaml
dependencies:
  web: ^1.0.0  # Ensure this is present or add it
```

Then run:
```bash
flutter pub get
```

---

## Browser Compatibility

The fix is compatible with all modern browsers that support the Web Audio API:

| Browser | Minimum Version | Notes |
|---------|----------------|-------|
| Chrome | 10+ | Full support |
| Firefox | 25+ | Full support |
| Safari | 6+ | Full support |
| Edge | 12+ | Full support |

**Valid oscillator type values** (per Web Audio API spec):
- `'sine'` - Sine wave (default)
- `'square'` - Square wave with 50% duty cycle
- `'sawtooth'` - Sawtooth wave
- `'triangle'` - Triangle wave
- `'custom'` - Custom waveform (requires `setPeriodicWave()`)

---

## Additional Issues Found

During analysis, **no other issues** were found in `audio_engine.dart`:

- ✅ Import statements are correct
- ✅ All other type assignments are correct
- ✅ No other `.toJS` misuses found
- ✅ Audio API usage follows best practices

The only issue is the single line at line 42.

---

## References

- [MDN: OscillatorNode.type](https://developer.mozilla.org/en-US/docs/Web/API/OscillatorNode/type)
- [package:web: OscillatorType](https://pub.dev/documentation/web/latest/web/OscillatorType.html)
- [package:web: OscillatorNode](https://pub.dev/documentation/web/latest/web/OscillatorNode-extension-type.html)
- [Dart: Getting started with JavaScript interop](https://dart.dev/interop/js-interop/start)
- [Web Audio API Specification](https://www.w3.org/TR/webaudio-1.1/)
