# PROPOSAL UX-003: Implement Unsaved Changes Confirmation

**Status:** Pending Approval  
**Priority:** P1 (High)  
**Effort:** Medium  
**Impact:** Medium  

---

## Problem Statement

Users can lose work by accidentally navigating away from forms:
1. User fills out song form
2. User taps back button or swipes back
3. Form closes without warning
4. All entered data is lost

This violates **Nielsen Heuristic #5: Error Prevention** - the app should prevent users from making mistakes.

---

## Proposed Solution

**Implement unsaved changes detection:**
1. Track if form has been modified from initial state
2. On back navigation, check for unsaved changes
3. If changes exist, show confirmation dialog
4. Options: "Discard", "Cancel", "Save"

---

## Implementation Details

### Files to Modify

1. `/lib/screens/songs/add_song_screen.dart`
2. `/lib/screens/bands/create_band_screen.dart`
3. `/lib/screens/setlists/create_setlist_screen.dart`
4. `/lib/widgets/confirmation_dialog.dart` (add new method)

### Code Changes

**AddSongScreen - Add dirty tracking:**
```dart
class _AddSongScreenState extends ConsumerState<AddSongScreen> {
  // ... existing fields ...
  bool _isDirty = false;

  void _markDirty() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;

    final result = await ConfirmationDialog.showUnsavedChangesDialog(context);
    if (result == UnsavedChangesResult.save) {
      await _saveSong();
      return true;
    }
    return result == UnsavedChangesResult.discard;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        // ... existing code ...
      ),
    );
  }
}
```

**Add to CustomTextField:**
```dart
// Add onChanged callback wrapper
onChanged: (value) {
  widget.onChanged?.call(value);
  _markDirty();
},
```

**Add dialog to ConfirmationDialog:**
```dart
enum UnsavedChangesResult { save, discard, cancel }

static Future<UnsavedChangesResult?> showUnsavedChangesDialog(
  BuildContext context,
) async {
  return showDialog<UnsavedChangesResult>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Unsaved Changes'),
      content: const Text(
        'You have unsaved changes. Would you like to save before leaving?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, UnsavedChangesResult.discard),
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, UnsavedChangesResult.cancel),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, UnsavedChangesResult.save),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
```

---

## User Impact

**Before:**
- Accidental data loss
- User frustration
- Need to re-enter all data

**After:**
- Safety net for navigation mistakes
- Option to save work
- Peace of mind when filling forms

---

## Success Metrics

- Reduced support tickets about lost data
- Increased form completion rate
- Improved user satisfaction

---

## Dependencies

- WillPopScope widget (Flutter built-in)
- ConfirmationDialog widget (existing)

---

## Risks

- **False positives:** Form might be marked dirty on accidental touch
  - **Mitigation:** Only mark dirty on actual value change, not focus
- **Annoyance:** Users might find dialog interrupting
  - **Mitigation:** Only show when actual changes detected

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| New form, no changes | No dialog, navigate immediately |
| Form with changes, save successful | Navigate after save |
| Form with changes, save failed | Stay on form, show error |
| Form with changes, discard selected | Navigate without saving |
| Form with changes, cancel selected | Stay on form |

---

## Approval

- [ ] MrUXUIDesigner Review
- [ ] MrStupidUser Approval
- [ ] Technical Feasibility Confirmed

---

**Created:** 2026-02-22  
**Last Updated:** 2026-02-22
