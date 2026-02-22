# PROPOSAL UX-010: Integrate Metronome with Song Workflow

**Status:** Pending Approval  
**Priority:** P1 (High)  
**Effort:** Medium  
**Impact:** High  

---

## Problem Statement

Metronome is isolated from song management:
1. User views song with BPM information
2. Wants to practice with metronome at song BPM
3. Must navigate to Metronome screen
4. Must manually enter BPM
5. Disconnected workflow

This violates **Nielsen Heuristic #8: Aesthetic and Minimalist Design** - extra steps create unnecessary friction.

---

## Proposed Solution

**Integrate metronome quick-launch:**

### Option A: Song Card Action
- Add metronome icon to song cards
- Tap launches metronome at song's BPM
- Metronome opens as bottom sheet (not full screen)

### Option B: Song Detail Integration
- Add "Practice with Metronome" section in song edit view
- One-tap launch with current BPM
- Option to adjust tempo for practice (50%, 75%, 100%)

### Option C: Floating Metronome
- Metronome can float over other screens
- User can view song and control metronome simultaneously
- Minimizable to corner button

---

## Implementation Details

### Files to Modify

1. `/lib/screens/songs/songs_list_screen.dart` - Add metronome action to song card
2. `/lib/screens/songs/add_song_screen.dart` - Add practice section
3. `/lib/screens/metronome_screen.dart` - Support bottom sheet presentation
4. `/lib/widgets/metronome_widget.dart` - Accept initial BPM parameter

### Code Changes

**Song Card - Add Metronome Button:**
```dart
// In _buildSongCard trailing row
if (song.ourBPM != null || song.originalBPM != null)
  IconButton(
    icon: const Icon(Icons.timer, size: 20),
    onPressed: () => _launchMetronome(context, ref, song),
    tooltip: 'Start Metronome',
  ),
```

**Launch Function:**
```dart
void _launchMetronome(BuildContext context, WidgetRef ref, Song song) {
  final bpm = song.ourBPM ?? song.originalBPM ?? 120;
  
  // Pass BPM to metronome
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MetronomeScreen(initialBpm: bpm),
    ),
  );
}
```

**MetronomeScreen - Accept Initial BPM:**
```dart
class MetronomeScreen extends StatefulWidget {
  final int? initialBpm;
  
  const MetronomeScreen({super.key, this.initialBpm});
  
  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  final _metronome = MetronomeService();
  
  @override
  void initState() {
    super.initState();
    if (widget.initialBpm != null) {
      _metronome.setBpm(widget.initialBpm!);
    }
    _metronome.addListener(_onMetronomeUpdate);
  }
  // ...
}
```

---

## User Impact

**Before:**
- Disconnected workflow
- Manual BPM entry
- Extra navigation steps

**After:**
- One-tap practice start
- Correct BPM automatically set
- Seamless workflow

---

## Success Metrics

- Increased metronome usage
- Reduced time to start practice session
- Improved user satisfaction

---

## Dependencies

- MetronomeService (existing)
- MetronomeWidget (existing)

---

## Risks

- **State management:** Metronome state needs to persist across navigation
  - **Mitigation:** Use Riverpod provider for metronome state
- **Audio interruption:** Metronome might stop when navigating
  - **Mitigation:** Ensure audio continues in background

---

## Future Enhancements

| Feature | Description | Priority |
|---------|-------------|----------|
| **Tempo scaling** | Practice at 50%, 75%, 100% of BPM | P2 |
| **Loop sections** | Mark and loop difficult sections | P3 |
| **Recording** | Record practice sessions | P3 |
| **Progress tracking** | Track practice time per song | P2 |

---

## Approval

- [ ] MrUXUIDesigner Review
- [ ] MrStupidUser Approval
- [ ] Technical Feasibility Confirmed

---

**Created:** 2026-02-22  
**Last Updated:** 2026-02-22
