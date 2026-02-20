# 🥁 Metronome Roadmap - RepSync Flutter App

**Current Status:** UI works, but no sound/timing  
**Goal:** Simple, working metronome  
**Reference:** Tack Android (patzly/tack-android)

---

## 🎯 PHASE 1: Basic Working Metronome (MVP) - PRIORITY

### Problem
Current implementation uses ChangeNotifier + Provider pattern which is overcomplicated.  
Sound playback doesn't work. Timing is broken.

### Solution: Simplify Everything

#### Task 1.1: Simplify State Management
**File:** `lib/providers/metronome_provider.dart`
- Remove ChangeNotifier pattern
- Use simple ValueNotifier or just StatefulWidget
- Keep it local to the widget

**Action:** Replace with simple singleton or service locator

#### Task 1.2: Fix Timing
**File:** `lib/services/metronome_service.dart`
- Use `Timer.periodic()` for beats
- Calculate interval: `Duration(milliseconds: 60000 ~/ bpm)`
- Simple callback on each beat

**Code:**
```dart
Timer? _timer;

void start(int bpm) {
  final interval = Duration(milliseconds: 60000 ~/ bpm);
  _timer = Timer.periodic(interval, (timer) {
    _onBeat();
  });
}
```

#### Task 1.3: Visual Feedback First
**File:** `lib/widgets/metronome_widget.dart`
- Make visual indicator work reliably
- Show beat circles lighting up
- Test timing is accurate

#### Task 1.4: Test MVP
- [ ] BPM slider changes speed
- [ ] Visual indicator shows beats
- [ ] Start/Stop works
- [ ] Timing is accurate (test with real metronome)

---

## 🔊 PHASE 2: Add Sound

### Task 2.1: Simple Sound Playback
**File:** `lib/services/metronome_service.dart`
- Use `audioplayers` package (already added)
- Load single click sound
- Play on each beat

**Code:**
```dart
final player = AudioPlayer();
await player.play(AssetSource('sounds/click.mp3'));
```

### Task 2.2: Add Accent Sound
- Higher pitch sound for beat 0
- Different audio file or pitch shift

### Task 2.3: Volume Control
- Slider for volume
- Apply to audio player

### Test Phase 2:
- [ ] Sound plays on each beat
- [ ] Accent on first beat
- [ ] Volume control works
- [ ] No audio lag/delay

---

## ✨ PHASE 3: Polish & Features

### Task 3.1: Time Signatures
- 2/4, 3/4, 4/4, 6/8
- Visual indicator for beat pattern
- Accent pattern changes

### Task 3.2: Tap BPM
- Button to tap tempo
- Calculate BPM from taps
- Average last 4-8 taps

### Task 3.3: Better UI
- Larger visual indicator
- Animation on beats
- Dark/Light theme

### Task 3.4: Integration
- Show song BPM on song screen
- Quick start metronome from song
- Save preferred BPM per song

---

## 📋 IMPLEMENTATION ORDER

### Immediate (Today)
1. ✅ Fix state management (simplify)
2. ✅ Fix timing (Timer.periodic)
3. ✅ Visual feedback working
4. ⏳ Basic sound playback

### Next (Tomorrow)
5. Accent sound
6. Volume control
7. Time signatures

### Later (Nice to Have)
8. Tap BPM
9. Song integration
10. Presets

---

## 🎯 SUCCESS CRITERIA

### MVP (Phase 1)
- [ ] Visual metronome works
- [ ] BPM 40-220 accurate
- [ ] Start/Stop reliable
- [ ] No crashes

### Full Feature (Phase 2)
- [ ] Sound plays on beats
- [ ] Accent on beat 1
- [ ] Volume control
- [ ] No audio lag

### Polished (Phase 3)
- [ ] Time signatures
- [ ] Tap BPM
- [ ] Nice UI
- [ ] Song integration

---

## 🚀 QUICK FIX PLAN

**Current Issue:** Provider pattern too complex, nothing works

**Solution:** 
1. Remove Provider/ChangeNotifier
2. Make MetronomeService a singleton
3. Use ValueNotifier for UI updates
4. Test with Timer first
5. Add sound after timing works

**Files to Simplify:**
- `metronome_provider.dart` → Make it a simple service
- `metronome_widget.dart` → Use ValueListenableBuilder
- `metronome_service.dart` → Fix Timer logic

---

**Priority:** PHASE 1 - Get basic timing working! 🎯
