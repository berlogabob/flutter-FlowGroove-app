# 🥁 Advanced Metronome Roadmap - RepSync Flutter App

**Current Status:** Basic visual metronome working  
**Goal:** Professional metronome with sound synthesis  
**Reference:** Reaper DAW, Tack Android  
**Timeline:** 2-3 weeks

---

## 📊 REQUIREMENTS SUMMARY

### From User
1. ✅ Sound generation (sine/square waves) - NO audio files
2. ✅ Two dropdown menus for time signature (X / Y)
3. ✅ Toggle for accent on first beat
4. ✅ Blinking visual on beat change
5. ✅ Professional UI/UX

---

## 🎯 PHASE 1: Sound Synthesis (PRIORITY - Week 1)

### Task 1.1: Choose Audio Approach

**Option A: Web Audio API (Web only)**
```dart
// Using web package for direct JS interop
import 'dart:js_util' as js_util;

final audioContext = js_util.newObject();
// Create oscillator, gain node, etc.
```

**Option B: flutter_sound package**
```dart
import 'package:flutter_sound/flutter_sound.dart';

final player = FlutterSound();
await player.openSession();
// Generate and play synthesized sound
```

**Option C: audioplayers with generated blobs**
```dart
// Generate WAV data in memory
// Play from bytes
```

**Decision:** Use **Web Audio API via dart:js_interop** for web, fallback to audioplayers for mobile

### Task 1.2: Implement Sound Synthesizer

**File:** `lib/services/metronome_sound.dart`

```dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class MetronomeSound {
  web.AudioContext? _audioContext;
  
  void init() {
    _audioContext = web.AudioContext();
  }
  
  Future<void> playClick({
    required bool isAccent,
    required String waveType, // 'sine' or 'square'
    required double volume,
  }) async {
    if (_audioContext == null) return;
    
    final oscillator = _audioContext!.createOscillator();
    final gainNode = _audioContext!.createGain();
    
    // Accent gets higher frequency
    oscillator.frequency.value = isAccent ? 1000 : 800;
    oscillator.type = waveType;
    
    // Short click sound (10ms)
    gainNode.gain.value = volume;
    
    oscillator.connect(gainNode);
    gainNode.connect(_audioContext!.destination);
    
    oscillator.start();
    oscillator.stop(_audioContext!.currentTime + 0.01);
  }
}
```

### Task 1.3: Add Wave Type Selector

**File:** `lib/widgets/metronome_widget.dart`

```dart
// Add dropdown/segmented button
SegmentedButton<String>(
  segments: const [
    ButtonSegment(value: 'sine', label: Text('Sine')),
    ButtonSegment(value: 'square', label: Text('Square')),
  ],
  selected: {_waveType},
  onSelectionChanged: (Set<String> selected) {
    setState(() => _waveType = selected.first);
  },
)
```

### Task 1.4: Test Sound

- [ ] Sine wave plays clean click
- [ ] Square wave plays sharper click
- [ ] Accent has higher pitch
- [ ] Volume control works
- [ ] No latency at 200+ BPM

**Success Criteria:** Sound plays instantly on beat, user can select wave type

---

## 🎼 PHASE 2: Time Signature UI (Week 2)

### Task 2.1: Replace Chip Buttons with Dropdowns

**File:** `lib/widgets/metronome_widget.dart`

**Current:**
```dart
Wrap(
  children: [2, 3, 4, 5, 6, 7].map((beats) => ChoiceChip(...))
)
```

**New:**
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // Numerator dropdown
    DropdownButton<int>(
      value: _numerator,
      items: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
          .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
          .toList(),
      onChanged: (value) => setState(() => _numerator = value!),
    ),
    
    const Text(' / ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    
    // Denominator dropdown
    DropdownButton<int>(
      value: _denominator,
      items: [4, 8].map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
      onChanged: (value) => setState(() => _denominator = value!),
    ),
  ],
)
```

### Task 2.2: Update Service

**File:** `lib/services/metronome_service.dart`

```dart
int _numerator = 4;      // Beats per measure
int _denominator = 4;    // Beat unit (4=quarter, 8=eighth)

void setTimeSignature(int numerator, int denominator) {
  _numerator = numerator;
  _denominator = denominator;
  _beatsPerMeasure = numerator; // For visual indication
  notifyListeners();
}
```

### Task 2.3: Display Format

**Visual:**
```
┌─────────────────┐
│  [4]  /  [4]    │
│   ▼       ▼     │
└─────────────────┘
```

**Large Display:**
```
╔═══════════════╗
║     4 / 4     ║
║  METRONOME    ║
╚═══════════════╝
```

### Task 2.4: Test Time Signatures

- [ ] Common: 2/4, 3/4, 4/4
- [ ] Complex: 5/4, 7/8, 9/8
- [ ] Odd: 11/8, 13/8
- [ ] Accent pattern follows numerator

**Success Criteria:** User can select any time signature, display is clear "X / Y"

---

## 🔊 PHASE 3: Accent System (Week 2-3)

### Task 3.1: Add Accent Toggle

**File:** `lib/widgets/metronome_widget.dart`

```dart
SwitchListTile(
  title: const Text('Accent on beat 1'),
  subtitle: const Text('Higher pitch on first beat'),
  value: _accentEnabled,
  onChanged: (value) {
    setState(() => _accentEnabled = value);
    _metronome.setAccentEnabled(value);
  },
)
```

### Task 3.2: Implement in Service

**File:** `lib/services/metronome_service.dart`

```dart
bool _accentEnabled = true;

void setAccentEnabled(bool enabled) {
  _accentEnabled = enabled;
  notifyListeners();
}

void _onTick(Timer timer) {
  _currentBeat = (_currentBeat + 1) % _numerator;
  
  final isAccent = _accentEnabled && _currentBeat == 0;
  _playClick(isAccent);
  
  notifyListeners();
}

void _playClick(bool isAccent) {
  final frequency = isAccent ? 1000.0 : 800.0;
  final waveType = _waveType; // 'sine' or 'square'
  final volume = isAccent ? _accentVolume : _volume;
  
  _soundSynth.playClick(
    isAccent: isAccent,
    waveType: waveType,
    volume: volume,
  );
}
```

### Task 3.3: Visual Accent Indicator

**File:** `lib/widgets/metronome_widget.dart`

```dart
// Beat circle
AnimatedContainer(
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: _metronome.isPlaying && _metronome.currentBeat == index
        ? (index == 0 && _accentEnabled ? Colors.red : Colors.blue)
        : Colors.grey.shade300,
    // Add glow effect for accented beat
    boxShadow: index == 0 && _accentEnabled && _metronome.currentBeat == 0
        ? [BoxShadow(color: Colors.red.shade400, blurRadius: 20, spreadRadius: 5)]
        : [],
  ),
)
```

### Task 3.4: Test Accent System

- [ ] Toggle switch works
- [ ] Accented beat has higher pitch
- [ ] Visual indicator shows accent
- [ ] Can disable accent if desired
- [ ] Accent volume is louder

**Success Criteria:** Clear audio and visual distinction for beat 1

---

## ✨ PHASE 4: Visual Polish (Week 3)

### Task 4.1: Blink Animation

**File:** `lib/widgets/metronome_widget.dart`

```dart
// Add animation controller
AnimationController _blinkController;
Animation<double> _blinkAnimation;

void _onMetronomeUpdate() {
  setState(() {});
  // Trigger blink
  _blinkController.forward(from: 0);
}

// In build:
FadeTransition(
  opacity: _blinkAnimation,
  child: Icon(...),
)
```

### Task 4.2: Beat Counter

**File:** `lib/screens/metronome_screen.dart`

```dart
// Large display
Text(
  '${_metronome.currentBeat + 1}',
  style: TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.bold,
    color: _metronome.currentBeat == 0 ? Colors.red : Colors.blue,
  ),
)
```

### Task 4.3: Professional Color Scheme

```dart
// Theme colors
const metronomePrimary = Color(0xFF2196F3);    // Blue
const metronomeAccent = Color(0xFFF44336);     // Red
const metronomeBackground = Color(0xFF121212); // Dark
const metronomeSurface = Color(0xFF1E1E1E);    // Card bg
```

### Task 4.4: Complete UI Mockup

```
┌─────────────────────────────────────┐
│  Metronome                      ✕   │
├─────────────────────────────────────┤
│                                     │
│           ╔═══════════╗             │
│           ║  BEAT 1   ║             │
│           ║     ●     ║             │
│           ╚═══════════╝             │
│                                     │
│        ◀─── 120 BPM ───▶            │
│         ━━━━━━━━━━━━━━              │
│                                     │
│      [4]  ▼    /    [4]  ▼          │
│                                     │
│   ○ ○ ○ ○  (beat indicators)        │
│                                     │
│   [Sine ▼]  [Accent: ON]            │
│                                     │
│   [    STOP    ]                    │
│                                     │
└─────────────────────────────────────┘
```

### Task 4.5: Test Visual Polish

- [ ] Blink animation smooth
- [ ] Beat counter accurate
- [ ] Colors professional
- [ ] Layout responsive
- [ ] Works on mobile and web

**Success Criteria:** Professional-looking metronome, smooth animations

---

## 📋 FILE MODIFICATION LIST

| File | Phase | Changes |
|------|-------|---------|
| `lib/services/metronome_sound.dart` | 1 | NEW - Sound synthesis |
| `lib/services/metronome_service.dart` | 1, 2, 3 | Add sound, time sig, accent |
| `lib/widgets/metronome_widget.dart` | 1, 2, 3, 4 | Complete UI rewrite |
| `lib/screens/metronome_screen.dart` | 4 | Visual polish |
| `pubspec.yaml` | 1 | Add web package dependency |

---

## 🎯 SUCCESS CRITERIA

### Phase 1 (Sound)
- [ ] Sine wave plays
- [ ] Square wave plays
- [ ] User can select wave type
- [ ] No external audio files needed

### Phase 2 (Time Signature)
- [ ] Two dropdowns (numerator/denominator)
- [ ] Display format "X / Y"
- [ ] Supports 2/4 to 12/8
- [ ] Clear visual representation

### Phase 3 (Accent)
- [ ] Toggle switch works
- [ ] Accented beat sounds different
- [ ] Visual accent indicator
- [ ] Volume control for accent

### Phase 4 (Polish)
- [ ] Blink animation on beats
- [ ] Professional UI
- [ ] Beat counter display
- [ ] Smooth performance

---

## ⏱️ TIMELINE

| Week | Phase | Deliverable |
|------|-------|-------------|
| 1 | Phase 1 | Working sound synthesis |
| 2 | Phase 2 + 3 | Time signature UI + Accent |
| 3 | Phase 4 | Visual polish + testing |

---

## 🚀 QUICK START (Today)

1. **Start with Phase 1, Task 1.2** - Implement basic sound synthesis
2. **Test immediately** - Verify sound plays
3. **Iterate** - Add wave type selector
4. **Move to Phase 2** - Update time signature UI

**Priority Order:**
1. 🔊 Sound (MUST HAVE)
2. 🎼 Time Signature Dropdowns (MUST HAVE)
3. 🔊 Accent Toggle (MUST HAVE)
4. ✨ Visual Polish (NICE TO HAVE)

---

**Status:** Ready to implement!  
**Next Step:** Start Phase 1 - Sound Synthesis 🎵
