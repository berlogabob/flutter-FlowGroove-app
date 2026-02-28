# Existing Tools Widgets Inventory

**Generated:** Sprint 4 - Metronome & Tuner Widget Analysis
**Total Widgets:** 15 (11 Metronome, 4 Tuner)
**Total Lines of Code:** 5,370

---

## Metronome Widgets

### CentralTempoCircle
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/metronome/central_tempo_circle.dart`
**Lines:** 509

- **Purpose:** Large rotary dial for tempo adjustment. Primary interaction point for changing BPM via drag gestures. Features pulse animation on beat, tick marks with labels (60, 120, 180 bpm), and center BPM display.
- **Parameters:** None (reads from `metronomeProvider`)
- **Output/Behavior:**
  - Displays current BPM in center (72-88px bold)
  - Rotary handle on edge showing BPM position
  - Progress ring visual indicator
  - Pulse animation synchronized with metronome beat
  - Drag gesture changes BPM (1-300 range, constant sensitivity)
  - Tap opens tempo change dialog
- **Dependencies:**
  - `MetronomeProvider`, `MetronomeState`
  - `MonoPulseTheme` (colors, typography, spacing, radius, animation)
  - `TempoChangeDialog`
  - `HapticFeedback`, `TickerProviderStateMixin`
- **Reusability:** ⭐⭐⭐ (3/5) - Tightly coupled to metronome state provider, but visual design could be extracted
- **Migration Priority:** **P0** - Core interaction widget, essential for metronome functionality

---

### BottomTransportBar
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/metronome/bottom_transport_bar.dart`
**Lines:** 272

- **Purpose:** Horizontal transport control bar at bottom of screen. Contains play/pause button and optional previous/next navigation for setlist playback.
- **Parameters:** None (reads from `metronomeProvider`)
- **Output/Behavior:**
  - Center: Large oval play/pause button (orange, 64-80px)
  - Left/Right: Previous/Next buttons (only when setlist loaded)
  - Pulse animation when playing
  - Haptic feedback on all interactions
  - Adaptive sizing for small screens
- **Dependencies:**
  - `MetronomeProvider`, `MetronomeState`
  - `MonoPulseTheme`
  - `HapticFeedback`
- **Reusability:** ⭐⭐⭐⭐ (4/5) - Well-structured with isolated button components, could be reused for other transport controls
- **Migration Priority:** **P0** - Essential transport controls

---

### BpmControlsWidget
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/metronome/bpm_controls_widget.dart`
**Lines:** 293

- **Purpose:** Secondary BPM controls with slider, numeric input field, and +/- buttons. Includes tooltip explaining BPM concept.
- **Parameters:** None (reads from `metronomeProvider`)
- **Output/Behavior:**
  - Slider (1-300 BPM, 299 divisions)
  - Numeric input field (1-300 validation)
  - Decrement/Increment buttons (-1/+1)
  - BPM label with help tooltip
  - Real-time state synchronization
- **Dependencies:**
  - `MetronomeProvider`
  - `MonoPulseTheme`
  - `HapticFeedback`
- **Reusability:** ⭐⭐⭐ (3/5) - Specific to BPM control, but slider/input pattern is reusable
- **Migration Priority:** **P1** - Secondary control method (CentralTempoCircle is primary)

---

### FineAdjustmentButtons
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/metronome/fine_adjustment_buttons.dart`
**Lines:** 305

- **Purpose:** Precise tempo adjustment buttons with icon-based values (-10, -5, -1, +1, +5, +10). Uses arrow count to indicate magnitude.
- **Parameters:** None (reads from `metronomeProvider`)
- **Output/Behavior:**
  - 6 buttons in horizontal row
  - Arrow icons: 1 (±1), 2 (±5), 3 (±10)
  - Scrollable on narrow screens
  - Haptic feedback on tap
  - Adaptive sizing for small screens
- **Dependencies:**
  - `MetronomeProvider`
  - `MonoPulseTheme`
  - `HapticFeedback`
- **Reusability:** ⭐⭐⭐⭐ (4/5) - Clean component structure, reusable pattern for incremental controls
- **Migration Priority:** **P1** - Useful but not essential (slider provides same functionality)

---

### FrequencyControlsWidget
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/metronome/frequency_controls_widget.dart`
**Lines:** 463

- **Purpose:** Advanced sound settings panel (collapsible). Contains wave type selector, volume slider, accent toggle, and frequency inputs.
- **Parameters:** None (reads from `metronomeProvider`)
- **Output/Behavior:**
  - Collapsible "Advanced Settings" header
  - Wave type dropdown (sine, square, triangle, sawtooth)
  - Volume slider (0-100%)
  - Accent on beat 1 toggle
  - Accent/Beat frequency input fields
  - Haptic feedback on interactions
- **Dependencies:**
  - `MetronomeProvider`
  - `MonoPulseTheme`
  - `HapticFeedback`
- **Reusability:** ⭐⭐⭐ (3/5) - Good internal component structure (`_WaveTypeDropdown`, `_OrangeSwitch`), but domain-specific
- **Migration Priority:** **P2** - Advanced feature, can be deferred

---

### MenuPopup
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/metronome/menu_popup.dart`
**Lines:** 487

- **Purpose:** Three-dots menu popup for song management operations. Provides save/update functionality for metronome settings.
- **Parameters:**
  - `Offset position` - Menu position on screen
  - `VoidCallback onClose` - Close handler
- **Output/Behavior:**
  - Positioned menu card (240px width)
  - Menu items: Save to Song, Save New Song, Update Song
  - Conditional display based on loaded song/setlist
  - Dialog confirmations for update operations
  - Song list and setlist selection dialogs
- **Dependencies:**
  - `MetronomeProvider`, `MetronomeState`
  - `Song`, `Setlist` models
  - `FirestoreService`, `FirebaseAuth`
  - `MonoPulseTheme`
  - `HapticFeedback`
- **Reusability:** ⭐⭐ (2/5) - Tightly coupled to Firebase and song management domain
- **Migration Priority:** **P1** - Important for data persistence, but can use simplified version initially

---

### SongLibraryBlock
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/metronome/song_library_block.dart`
**Lines:** 562

- **Purpose:** Song and setlist library browser. Compact pill button expands to slide-up panel with song/setlist lists.
- **Parameters:** None (reads from providers)
- **Output/Behavior:**
  - Compact mode: Pill button with "Song Library" text
  - Expanded mode: Slide-up panel (70% max height)
  - Tab toggle: Songs / Setlists
  - Song cards with title, artist, BPM badge
  - Setlist cards with name, description, song count
  - Load song/setlist on tap
  - Async data loading with error handling
- **Dependencies:**
  - `MetronomeProvider`
  - `SongsProvider`, `SetlistsProvider`
  - `Song`, `Setlist` models
  - `ErrorBanner` widget
  - `MonoPulseTheme`
  - `HapticFeedback`
- **Reusability:** ⭐⭐⭐ (3/5) - Good component separation (`_SongCard`, `_SetlistCard`), but tied to data providers
- **Migration Priority:** **P1** - Core library browsing functionality

---

### TempoChangeDialog
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/metronome/tempo_change_dialog.dart`
**Lines:** 401

- **Purpose:** Modal dialog for changing tempo via Tap or Keyboard input modes.
- **Parameters:**
  - `int bpm` - Current BPM value
- **Output/Behavior:**
  - Mode selection: Tap / Keyboard buttons
  - Keyboard mode: Numeric input field (1-600 validation)
  - Tap mode: Info message about tap rhythm feature
  - "Apply instantly" toggle switch
  - Cancel / Apply action buttons
  - Returns result: `{bpm, applyInstantly}`
- **Dependencies:**
  - `MonoPulseTheme`
  - `HapticFeedback`
- **Reusability:** ⭐⭐⭐⭐ (4/5) - Self-contained dialog, reusable pattern for mode selection
- **Migration Priority:** **P1** - Important alternative tempo input method

---

### TimeSignatureBlock
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/metronome/time_signature_block.dart`
**Lines:** 722 ⚠️

- **Purpose:** Visual beat pattern editor with tappable circles for beats and subdivisions. Supports beat mode cycling (normal → accent → silent).
- **Parameters:** None (reads from `metronomeProvider`)
- **Output/Behavior:**
  - Two rows: Beats (top) and Subdivisions (bottom)
  - Scrollable circle lists with +/- buttons
  - Tap circles to cycle beat modes
  - Visual feedback: colors and glow for active beats
  - Mode indicators: white dot for accent/silent
  - Badge on + button when items exceed visible count
  - Adaptive sizing for small screens
- **Dependencies:**
  - `MetronomeProvider`
  - `BeatMode` enum
  - `MonoPulseTheme`
  - `HapticFeedback`
- **Reusability:** ⭐⭐⭐ (3/5) - Complex but well-structured with isolated components (`_BeatsRow`, `_SubdivisionsRow`, `_BeatCircleWithMode`)
- **Migration Priority:** **P0** - Core beat pattern functionality
- **⚠️ CODE SMELL:** 722 lines - Exceeds 200 line threshold. Consider splitting into separate files for rows and circle components.

---

### TimeSignatureControlsWidget
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/metronome/time_signature_controls_widget.dart`
**Lines:** 221

- **Purpose:** Preset time signature selector with chip buttons for common signatures (4/4, 3/4, 6/8, 2/4, 5/4, 7/8).
- **Parameters:** None (reads from `metronomeProvider`)
- **Output/Behavior:**
  - 6 preset chips in Wrap layout
  - Selected state highlighting
  - Current selection display badge
  - Help tooltip explaining time signature
  - Haptic feedback on tap
- **Dependencies:**
  - `MetronomeProvider`
  - `TimeSignature` model
  - `MonoPulseTheme`
  - `HapticFeedback`
- **Reusability:** ⭐⭐⭐⭐⭐ (5/5) - Clean, self-contained, reusable preset selector pattern
- **Migration Priority:** **P1** - Convenient UX enhancement

---

### AccentPatternEditorWidget
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/metronome/accent_pattern_editor_widget.dart`
**Lines:** 252 ⚠️

- **Purpose:** Visual toggle buttons for accent pattern per beat. Each beat shows beat number, toggle button, and label (Accent/Regular).
- **Parameters:** None (reads from `metronomeProvider`)
- **Output/Behavior:**
  - Dynamic button count based on time signature numerator
  - Toggle buttons: star (accent) / circle (regular)
  - Reset button to restore default from time signature
  - Pulse animation on accent toggle
  - Help tooltip
- **Dependencies:**
  - `MetronomeProvider`
  - `MonoPulseTheme`
  - `HapticFeedback`
- **Reusability:** ⭐⭐⭐⭐ (4/5) - Clean toggle button component, reusable pattern
- **Migration Priority:** **P2** - Advanced feature, can be deferred
- **⚠️ CODE SMELL:** 252 lines - Slightly exceeds 200 line threshold. Could extract `_AccentToggleButton` to separate file.

---

## Tuner Widgets

### CentralDial
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/tuner/central_dial.dart`
**Lines:** 346

- **Purpose:** Main tuner display showing current note and frequency. Interactive dial for frequency adjustment (Generate mode) or needle indicator (Listen mode).
- **Parameters:** None (reads from `tunerProvider`)
- **Output/Behavior:**
  - Large circle (50-60% screen width)
  - Center display: Note (e.g., "A4") + Frequency or Cents
  - Generate mode: Rotating handle for frequency drag adjustment
  - Listen mode: Needle indicator for cents deviation (-50 to +50)
  - Tick marks around perimeter
  - Haptic feedback on frequency changes
- **Dependencies:**
  - `TunerProvider`, `tunerCentsProvider`
  - `TunerMode` enum
  - `TickMarks` widget
  - `MonoPulseTheme`
  - `HapticFeedback`
- **Reusability:** ⭐⭐⭐ (3/5) - Domain-specific to tuner, but dial interaction pattern is reusable
- **Migration Priority:** **P0** - Core tuner functionality

---

### ModeSwitcher
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/tuner/mode_switcher.dart`
**Lines:** 162

- **Purpose:** Two-pill mode selector for switching between "Generate Tone" and "Listen & Tune" modes.
- **Parameters:** None (reads from `tunerProvider`)
- **Output/Behavior:**
  - Two horizontal pills
  - Fade animation on mode change (250ms)
  - Active: orange background, white text
  - Inactive: surface background, secondary text
  - Haptic feedback on tap
- **Dependencies:**
  - `TunerProvider`, `tunerModeProvider`
  - `TunerMode` enum
  - `MonoPulseTheme`
  - `HapticFeedback`
- **Reusability:** ⭐⭐⭐⭐⭐ (5/5) - Excellent reusable pattern for binary mode selection
- **Migration Priority:** **P0** - Essential mode switching

---

### TickMarks
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/tuner/tick_marks.dart`
**Lines:** 146

- **Purpose:** Static tick marks around tuner dial. Displays 12 positions with labels for key frequencies (A4/440, E4/330, D4/294).
- **Parameters:**
  - `double size` - Circle diameter
- **Output/Behavior:**
  - 12 tick marks (every 30 degrees)
  - Major ticks with labels (A4, E4, D4)
  - Sub-labels for frequencies (440, 330, 294)
  - Thin lines (#333333), labels (#8A8A8F)
- **Dependencies:**
  - `MonoPulseTheme`
- **Reusability:** ⭐⭐⭐⭐⭐ (5/5) - Pure visual component, no state, fully reusable
- **Migration Priority:** **P0** - Required for tuner visual design

---

### TransportBar
**File:** `/Users/berloga/Documents/GitHub/flutter_repsync_app/lib/widgets/tuner/transport_bar.dart`
**Lines:** 229

- **Purpose:** Bottom transport control bar for tuner. Contains volume control, play/stop button, and settings placeholder.
- **Parameters:** None (reads from `tunerProvider`)
- **Output/Behavior:**
  - Left: Volume icon with tap-to-toggle slider
  - Center: Play/Stop or Listen button (mode-dependent)
  - Right: Settings icon (placeholder)
  - Generate mode: Play/Stop controls tone generation
  - Listen mode: Start/Stop controls microphone
  - Haptic feedback on all interactions
- **Dependencies:**
  - `TunerProvider`, `TunerMode`
  - `MonoPulseTheme`
  - `HapticFeedback`
- **Reusability:** ⭐⭐⭐⭐ (4/5) - Well-structured with isolated components (`_VolumeControl`, `_IconButton`)
- **Migration Priority:** **P0** - Essential transport controls

---

## Code Smells Identified

### 1. Overly Complex Widgets (>200 lines)

| Widget | Lines | Severity | Recommendation |
|--------|-------|----------|----------------|
| `TimeSignatureBlock` | 722 | 🔴 High | Split into separate files: `beats_row.dart`, `subdivisions_row.dart`, `beat_circle.dart` |
| `CentralTempoCircle` | 509 | 🟡 Medium | Extract `_TickMarks`, `_RotaryDial`, `_BpmDisplay` to separate files |
| `MenuPopup` | 487 | 🟡 Medium | Extract dialog methods to separate service class |
| `FrequencyControlsWidget` | 463 | 🟡 Medium | Extract `_WaveTypeDropdown`, `_OrangeSwitch` to shared components |
| `SongLibraryBlock` | 562 | 🟡 Medium | Extract `_SongCard`, `_SetlistCard` to separate files |
| `TempoChangeDialog` | 401 | 🟡 Medium | Extract `_ModeButton`, `_ActionButton` to shared components |
| `FineAdjustmentButtons` | 305 | 🟢 Low | Acceptable complexity, but `_TempoButton` could be extracted |
| `BpmControlsWidget` | 293 | 🟢 Low | Acceptable complexity |
| `BottomTransportBar` | 272 | 🟢 Low | Acceptable complexity |
| `AccentPatternEditorWidget` | 252 | 🟢 Low | Extract `_AccentToggleButton` to separate file |

### 2. Duplicated Code

**Pattern: Haptic Feedback + State Update**
- Found in: Most widgets
- Example:
```dart
onTap: () {
  HapticFeedback.lightImpact();
  metronome.adjustTempoFine(-10);
}
```
- **Recommendation:** Create utility function `withHaptic(VoidCallback callback)` in common utils

**Pattern: AnimatedScale with Press State**
- Found in: `_PlayButton`, `_NavigationButton`, `_TempoButton`, `_TimeSignatureChip`, etc.
- **Recommendation:** Extract to reusable `AnimatedButton` widget

**Pattern: MonoPulseTheme References**
- All widgets use same theme constants
- **Status:** ✅ Good - Properly centralized

### 3. Tight Coupling

| Widget | Coupling Issue | Impact |
|--------|----------------|--------|
| `MenuPopup` | Direct Firebase Auth + Firestore calls | Hard to test, hard to reuse |
| `SongLibraryBlock` | Direct provider consumption for songs/setlists | Tied to specific data structure |
| `CentralTempoCircle` | Direct `metronomeProvider` access | Cannot use with other state sources |
| All Widgets | `MonoPulseTheme` dependency | ⚠️ Acceptable - This is intentional design system coupling |

### 4. Missing Null Safety

**Status:** ✅ GOOD - All widgets use proper null safety:
- `late` keyword used appropriately for initialized variables
- Null-aware operators (`.?`, `??`) used correctly
- Controller disposal in `dispose()` methods
- `mounted` checks before async callbacks

**Minor Issues:**
- `TimeSignatureBlock._BeatsRow._buildScrollableCircles`: Division operator could have null issue if `circleWidth` is 0 (unlikely but possible)
- `CentralTempoCircle._getAngle`: Default size parameter `170` is magic number - should be constant

---

## Migration Recommendations

### Priority Matrix

| Priority | Widgets | Rationale |
|----------|---------|-----------|
| **P0** | `CentralTempoCircle`, `BottomTransportBar`, `TimeSignatureBlock`, `CentralDial`, `ModeSwitcher`, `TickMarks`, `TransportBar` | Core functionality - app cannot function without these |
| **P1** | `BpmControlsWidget`, `FineAdjustmentButtons`, `MenuPopup`, `SongLibraryBlock`, `TempoChangeDialog`, `TimeSignatureControlsWidget` | Important UX features - should be migrated in first sprint after core |
| **P2** | `FrequencyControlsWidget`, `AccentPatternEditorWidget` | Advanced features - can be deferred to later sprints |

### Migration Strategy

1. **Phase 1 (P0):** Extract and migrate core interaction widgets
   - Focus on `CentralTempoCircle` and `TimeSignatureBlock` first (largest, most complex)
   - Split large files before migration
   - Create shared `AnimatedButton` component to reduce duplication

2. **Phase 2 (P1):** Migrate secondary controls and data management
   - `SongLibraryBlock` requires data provider setup
   - `MenuPopup` needs Firebase abstraction layer first

3. **Phase 3 (P2):** Advanced features
   - Can be simplified or replaced with native controls if needed

### Reusability Opportunities

**High Reusability (Extract to Shared Components):**
1. `_OrangeSwitch` → `shared/toggle_switch.dart`
2. `_TimeSignatureChip` → `shared/preset_chip.dart`
3. `_ModeButton` → `shared/mode_selector.dart`
4. `_IconButton` → `shared/icon_button.dart`
5. `AnimatedScale` + press state pattern → `shared/animated_button.dart`

**Theme Compliance:**
- ✅ All widgets properly use `MonoPulseTheme`
- ✅ Consistent spacing, colors, typography, radius
- ✅ Animation durations follow standards (120ms short, 250ms medium)
- ✅ Touch zones meet 48px minimum requirement

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Total Widgets | 15 |
| Metronome Widgets | 11 |
| Tuner Widgets | 4 |
| P0 Priority | 7 |
| P1 Priority | 6 |
| P2 Priority | 2 |
| Widgets >200 lines | 10 |
| Widgets >500 lines | 3 |
| Reusability ⭐⭐⭐⭐⭐ | 3 |
| Reusability ⭐⭐⭐⭐ | 4 |
| Reusability ⭐⭐⭐ | 6 |
| Reusability ⭐⭐ | 1 |
