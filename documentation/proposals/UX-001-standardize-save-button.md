# PROPOSAL UX-001: Standardize Save Button Placement

**Status:** Pending Approval  
**Priority:** P0 (Critical)  
**Effort:** Low  
**Impact:** High  

---

## Problem Statement

Save button placement is inconsistent across the application:
- **AddSongScreen:** Save button in AppBar (top-right)
- **CreateSetlistScreen:** Save button in AppBar (top-right)
- **CreateBandScreen:** Save button at form bottom (correct pattern)

This inconsistency:
1. Violates user expectations for form completion flow
2. Creates ergonomic issues (top-right is outside thumb zone on mobile)
3. Reduces discoverability of the save action
4. Breaks the natural F-pattern scanning behavior

---

## Proposed Solution

**Standardize all save buttons to:**
- Position: Bottom of form, after all input fields
- Width: Full-width (matches form field width)
- Style: ElevatedButton with primary color
- Label: Contextual ("Save", "Create Band", "Create Setlist")
- Loading state: Show CircularProgressIndicator inline

---

## Implementation Details

### Files to Modify

1. `/lib/screens/songs/add_song_screen.dart`
   - Remove Save from AppBar actions
   - Add full-width button at bottom of ListView

2. `/lib/screens/setlists/create_setlist_screen.dart`
   - Remove Save from AppBar actions
   - Add full-width button at bottom of form

3. `/lib/screens/bands/create_band_screen.dart`
   - No changes needed (already correct)

### Code Changes

**AddSongScreen - Before:**
```dart
appBar: AppBar(
  title: Text(_isEditing ? 'Edit Song' : 'Add Song'),
  actions: [
    TextButton(
      onPressed: _saveSong,
      child: const Text('Save', style: TextStyle(color: Colors.white)),
    ),
  ],
),
```

**AddSongScreen - After:**
```dart
appBar: AppBar(
  title: Text(_isEditing ? 'Edit Song' : 'Add Song'),
),
body: ListView(
  padding: const EdgeInsets.all(16),
  children: [
    // ... existing form fields ...
    const SizedBox(height: 32),
    // Save button at bottom
    CustomButton(
      label: _isEditing ? 'Save Changes' : 'Create Song',
      onPressed: _saveSong,
      isLoading: _isSaving,
      fullWidth: true,
      size: ButtonSize.large,
    ),
    const SizedBox(height: 16),
  ],
),
```

---

## User Impact

**Before:**
- Users must look up to find save action
- Thumb must stretch to top of screen
- Inconsistent with other forms

**After:**
- Natural flow: fill form → scroll to bottom → tap save
- Ergonomic thumb-friendly placement
- Consistent across all forms

---

## Success Metrics

- Reduced time to complete form submission
- Decreased support tickets about "can't find save"
- Improved user satisfaction scores

---

## Dependencies

- CustomButton widget (already exists)
- No backend changes required

---

## Risks

- Minimal risk; purely visual change
- Users accustomed to current placement may need brief adjustment

---

## Approval

- [ ] MrUXUIDesigner Review
- [ ] MrStupidUser Approval
- [ ] Technical Feasibility Confirmed

---

**Created:** 2026-02-22  
**Last Updated:** 2026-02-22
