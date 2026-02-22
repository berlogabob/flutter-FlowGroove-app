# PROPOSAL UX-002: Add Undo Functionality After Delete

**Status:** Pending Approval  
**Priority:** P0 (Critical)  
**Effort:** Medium  
**Impact:** High  

---

## Problem Statement

Current delete operations are irreversible:
1. User swipes to delete a song
2. Confirmation dialog appears
3. After confirmation, item is immediately deleted
4. No way to recover if accidental

This violates **Nielsen Heuristic #3: User Control and Freedom** - users need an "emergency exit" for accidental actions.

---

## Proposed Solution

**Implement undo functionality:**
1. After deletion, show SnackBar with "Undo" action
2. Item remains in memory for 5 seconds
3. If undo tapped, restore item to list
4. If timeout expires, permanently delete

---

## Implementation Details

### Files to Modify

1. `/lib/screens/songs/songs_list_screen.dart`
   - Modify onDismissed callback
   - Add undo logic with temporary state

2. `/lib/widgets/confirmation_dialog.dart`
   - No changes needed

### Code Changes

**SongsListScreen - Before:**
```dart
onDismissed: (direction) async {
  final user = ref.read(currentUserProvider);
  if (user != null) {
    await ref.read(firestoreProvider).deleteSong(song.id, user.uid);
  }
},
```

**SongsListScreen - After:**
```dart
onDismissed: (direction) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;

  // Store song for potential undo
  final deletedSong = song;
  final songIndex = filteredSongs.indexOf(song);

  // Optimistically remove from UI
  setState(() {
    filteredSongs.removeAt(songIndex);
  });

  // Show undo snackbar
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  scaffoldMessenger.showSnackBar(
    SnackBar(
      content: Text('"${song.title}" deleted'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          // Restore song
          setState(() {
            filteredSongs.insert(songIndex, deletedSong);
          });
        },
      ),
      duration: const Duration(seconds: 5),
    ),
  );

  // Wait for snackbar duration, then permanently delete
  await Future.delayed(const Duration(seconds: 5));
  await ref.read(firestoreProvider).deleteSong(song.id, user.uid);
},
```

---

## User Impact

**Before:**
- Accidental deletion = data loss
- User frustration and potential support requests
- Fear of using swipe gesture

**After:**
- Safety net for mistakes
- Increased confidence in using app
- Better user experience

---

## Success Metrics

- Reduced support tickets for data recovery
- Increased user satisfaction with delete flow
- No increase in accidental permanent deletions

---

## Dependencies

- SnackBar widget (Flutter built-in)
- State management for optimistic UI updates

---

## Risks

- **Data consistency:** If app closes during undo window, item may be deleted without being saved to Firestore
  - **Mitigation:** Show different message if deletion is pending sync
- **Memory:** Keeping deleted items in memory temporarily
  - **Mitigation:** 5-second window is negligible for memory

---

## Alternative Approaches

| Approach | Pros | Cons |
|----------|------|------|
| **Current proposal (SnackBar undo)** | Simple, familiar pattern | Short undo window |
| **Trash/Recycle bin** | Longer recovery window | More complex UI |
| **No confirmation, just undo** | Faster workflow | More accidental deletions |
| **Keep confirmation + undo** | Maximum safety | Extra tap for intentional deletes |

**Recommendation:** Start with current proposal; consider trash bin for future if users request longer recovery window.

---

## Approval

- [ ] MrUXUIDesigner Review
- [ ] MrStupidUser Approval
- [ ] Technical Feasibility Confirmed

---

**Created:** 2026-02-22  
**Last Updated:** 2026-02-22
