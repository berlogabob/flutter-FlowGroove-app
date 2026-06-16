## ARCHITECTURE DECISION: Tuner Improvements (MVP Scope)

### Context Analysis

**Current State:**
- Tuner screen has 2 modes: Generate Tone (sine wave) and Listen & Tune (mic pitch detection)
- UI: Mode switcher → Central dial → Transport bar (volume, play/stop, settings placeholder)
- **Broken buttons identified:**
  1. **Settings button** (`_IconButton` in `transport_bar.dart`) — taps do nothing (placeholder callback)
  2. **Volume control** — tap toggles slider visibility but slider is never shown (UI incomplete)
  3. **Mute concern** — volume button already handles mute at volume=0; no separate mute needed

**Market Research Insights (from ToDo_tuner.md):**
- #1 user demand: **minimalism** — "opened app, tuned in 10 seconds, no clutter"
- Offline-first, no ads, no paywalls
- Regional instruments (Cavaquinho/BR, Balalaika/RU, Sitar/IN) as differentiator
- Users hate: settings buried in menus, перегруженность (overload)
- Pro users want: Hz display, cents precision ±0.1, calibration (A=432/440/442)

### Components

| Component | Responsibility | Dependencies |
|---|---|---|
| `TunerScreen` | Main screen layout, mode switching | `ToolScreenScaffold`, `ToolModeSwitcher` |
| `CentralDial` | Interactive frequency dial with drag | `TickMarks`, `NoteScaleRuler` (NEW) |
| `TickMarks` | Static tick marks around dial | None |
| `NoteScaleRuler` (NEW) | Chromatic note labels around dial edge | `MonoPulseTheme` |
| `TransportBar` | Play/stop, volume, settings | `TunerNotifier` |
| `TunerSettingsSheet` (NEW) | Bottom sheet for calibration, haptics, reference freq | `SharedPreferences` or `Hive` |
| `TunerNotifier` | State management (Riverpod Notifier) | `ToneGenerator`, `PitchDetector` |
| `TunerState` | Immutable state model | None |

### Data Flow

```text
User gestures (drag dial) → GestureDetector → Notifier.updateFrequency()
  → State update (frequency, note, cents) → CentralDial rebuild
  → TickMarks + NoteScaleRuler read from state → repaint

User taps Play → TransportBar → Notifier.togglePlaying()
  → ToneGenerator.startTone(freq, volume) → Audio output

User taps mic → TransportBar → Notifier.toggleListening()
  → PitchDetector.startListening() → onPitchDetected callback
  → Notifier._handlePitchDetection() → State update (freq, note, cents)

User taps Settings → TransportBar → showBottomSheet(TunerSettingsSheet)
  → User adjusts calibration → Notifier.setCalibration() → State update
  → All frequency calculations use new reference A4
```

### State Management

- **Provider:** `tunerProvider` (NotifierProvider<TunerNotifier, TunerState>)
- **State managed:**
  - `mode` (TunerMode.generate | listen)
  - `frequency` (double, 20-2000 Hz)
  - `note` (String, e.g. "A4")
  - `cents` (int, -50 to +50)
  - `isPlaying` (bool)
  - `isListening` (bool)
  - `volume` (double, 0.0-1.0)
  - **NEW:** `referenceA4` (double, default 440.0 — calibration)
  - **NEW:** `hapticEnabled` (bool, default true)
  - **NEW:** `selectedInstrument` (String?, for future instrument presets)

### MVP vs Nice-to-Have

#### MVP (This Sprint)
| Priority | Feature | Rationale |
|---|---|---|
| P0 | Fix settings button → open bottom sheet | Broken UI, users expect it to work |
| P0 | Add note scale ruler around dial | Explicit user request |
| P1 | Settings: A4 calibration slider (432-445 Hz) | Pro user demand, RU market request |
| P1 | Settings: Haptic feedback toggle | Market research — some users hate vibration |
| P2 | Fix volume slider (show/hide properly) | Existing broken UI |
| P2 | Remove duplicate mute functionality | User feedback — play/stop already toggles |

#### Future (Post-MVP)
| Priority | Feature | Rationale |
|---|---|---|
| P3 | Instrument library (JSON-based) | Regional instruments — needs data layer |
| P3 | Auto/Manual note detection mode | Complex audio algorithm changes |
| P3 | Custom tuning editor | Needs persistence layer |
| P3 | Stage mode (minimal UI after timeout) | Nice-to-have UX polish |
| P3 | Noise filter level settings | Requires audio algorithm tuning |

### Implementation Plan

#### 1. Fix Settings Button (P0)
**File:** `lib/widgets/tuner/transport_bar.dart`
- Replace placeholder `_IconButton` callback with `showModalBottomSheet`
- Open `TunerSettingsSheet` (new widget)
- Use existing `tune_outlined` icon or switch to `settings_outlined`

**File:** `lib/widgets/tuner/tuner_settings_sheet.dart` (NEW)
```text
TunerSettingsSheet (StatelessWidget)
├── Section: Calibration
│   └── Slider: 432 Hz — 440 Hz — 445 Hz
│       └── Label: "A4 Reference: ${value.round()} Hz"
├── Section: Feedback
│   └── SwitchListTile: "Haptic Feedback"
├── Section: About
│   └── Text: "Pitch detection: YIN algorithm"
│   └── Text: "Offline-first — no internet required"
```

**Settings Content Decision:**
Based on market research (minimalism is #1), settings should be **sparse**:
- A4 calibration (432-445 Hz) — requested by RU/pro users
- Haptic toggle — accessibility preference
- No theme switching (app already has theme)
- No noise filter (algorithm-level, not user-facing yet)
- No account/cloud settings (fully offline)

#### 2. Add Note Scale Ruler (P0)
**File:** `lib/widgets/tuner/note_scale_ruler.dart` (NEW)

Chromatic note labels around the dial perimeter:
- 12 notes: C, C#, D, D#, E, F, F#, G, G#, A, A#, B
- Positioned at equal angular intervals (30° each)
- Style: 12px Regular, `textSecondary` color
- Highlighted when current frequency matches that note
- Start from top (C) going clockwise
- Octave indicator shown below note (e.g., "C4")
- Octave changes based on current frequency range

**Integration:**
- Add as child in `CentralDial`'s `Stack` (outside main circle, at tick marks level)
- Reuse `TickMarks` angular positioning logic
- Current note highlight: `accentOrange` color, slightly larger font

#### 3. Fix Volume Control (P2)
**File:** `lib/widgets/tuner/transport_bar.dart`
- `_VolumeControl` currently toggles `_isSliderVisible` but never shows slider
- Options:
  - **A:** Add expanding slider row (tap volume icon → slider appears above transport bar)
  - **B:** Remove volume icon, control volume via settings sheet
  - **C:** Replace with simple mute toggle (tap = mute/unmute)

**Recommendation:** Option C — simplest, aligns with user feedback that mute duplicates play/stop.
  - When playing: volume icon shows current level
  - Tap volume: cycles through 0% → 50% → 100% (3 states with haptic)
  - Visual feedback: icon changes (volume_off / volume_down / volume_up)
  - Removes need for slider UI entirely

#### 4. Update TunerState & Provider (P1)
**File:** `lib/providers/tuner_provider.dart`
- Add `referenceA4` field (default 440.0)
- Add `hapticEnabled` field (default true)
- Update `_frequencyToNote()` to use `referenceA4` instead of hardcoded 440.0
- Add `setCalibration(double)` method
- Add `toggleHaptic()` method
- Update `calculateCents()` to use `referenceA4`
- Persist settings via `Hive` (offline-first pattern already used in app)

#### 5. Update Frequency-Note Calculation (P1)
**File:** `lib/providers/tuner_provider.dart`

Current calculation uses hardcoded `referenceFrequency = 440.0`.
Update to use `state.referenceA4`:

```dart
NoteData _frequencyToNote(double frequency) {
  final referenceFrequency = state.referenceA4; // was: 440.0
  const referenceNoteIndex = 69; // MIDI note number for A4
  // ... rest unchanged
}
```

This allows users to tune to A=432 Hz (esoteric/classical music) or A=442 Hz (orchestral standard).

### Offline Strategy
- **Cache:** Settings (referenceA4, hapticEnabled) stored in Hive box `tuner_settings`
- **Sync:** None needed — tuner is 100% offline-first
- **Conflict:** N/A — no cloud sync for tuner settings
- **Fallback:** If Hive read fails, use defaults (440 Hz, haptic on)

### Fail-Safe
- **Cache fallback:** Settings default to 440 Hz reference, haptic enabled
- **Permission handling:** Microphone permission denied → show snackbar, disable Listen mode
- **Null safety:** Ensured — all state fields have defaults, frequency clamped 20-2000 Hz
- **Audio errors:** Tone generation failures caught and logged, UI reverts to stopped state

### Validation Notes
- Aligns with market research (minimalism, offline-first, pro features)
- Follows existing architecture (Riverpod Notifier pattern, MonoPulse theme)
- No new dependencies required (uses existing Hive, Flutter material)
- Deviation: Volume control simplified to 3-state cycle instead of slider (user feedback alignment)
- Note scale ruler is user-requested feature not in `ToDo_tuner.md` and complements the existing tick marks
- Instrument library (JSON) deferred to post-MVP because it requires a broader data layer

### Files To Modify

| File | Action | Priority |
|---|---|---|
| `lib/widgets/tuner/transport_bar.dart` | Fix settings button, simplify volume | P0 |
| `lib/widgets/tuner/tuner_settings_sheet.dart` | Create settings bottom sheet | P0 |
| `lib/widgets/tuner/note_scale_ruler.dart` | Create chromatic note labels | P0 |
| `lib/widgets/tuner/central_dial.dart` | Integrate note scale ruler in `Stack` | P0 |
| `lib/providers/tuner_provider.dart` | Add `referenceA4`, `hapticEnabled`, persistence | P1 |
| `lib/widgets/tuner/tick_marks.dart` | Optional tick-density adjustment | P2 |

### Estimated Effort
- P0 items: 2-3 hours
- P1 items: 1-2 hours
- P2 items: 30 min
- **Total: 4-5.5 hours**
