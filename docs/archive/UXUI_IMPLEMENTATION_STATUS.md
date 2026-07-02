# UX/UI Improvement Plan - Implementation Status

**Date:** June 15, 2026  
**Version:** v0.13.x  
**Status:** In Progress

---

## Executive Summary

Implementation of the UX/UI Improvement Plan from `docs/UXUI_IMPROVEMENT_PLAN.md` is underway. Phases 1-3 are complete, Phase 4-5 components are created, and remaining work is documented below.

---

## Phase 1: Surface Primary Actions ✅ COMPLETE

**Goal:** No primary action is ever hidden.

### 1.1 ✅ Build PrimaryActionBar Component
- **Status:** Complete
- **File:** `lib/widgets/primary_action_bar.dart`
- **Details:** Created reusable bottom action bar widget with safe area awareness
- **Features:**
  - Full-width CustomButton
  - Optional secondary action button
  - Loading state support
  - Elevation with Material Design

### 1.2 ✅ Add Persistent Create Setlist CTA
- **Status:** Complete
- **File:** `lib/screens/setlists/create_setlist_screen.dart`
- **Changes:**
  - Added `PrimaryActionBar` to bottomNavigationBar
  - Removed "Save" action from overflow menu
  - Button displays "Create Setlist" or "Save Changes" (edit mode)

### 1.3 ✅ Sweep All Create/Edit Forms
- **Status:** Complete
- **Updated Files:**
  - `lib/screens/setlists/create_setlist_screen.dart` ✅
  - `lib/screens/bands/create_band_screen.dart` ✅
  - `lib/screens/songs/add_song_screen.dart` ✅
  - `lib/screens/profile_screen.dart` (inline editing - no change needed)

**Phase 1 Exit Criteria:** ✅ All form screens have visible primary CTAs

---

## Phase 2: Selection-State Clarity ✅ COMPLETE

**Goal:** A user can always tell what's selected.

### 2.1 ✅ Define Selected vs Unselected Chip Styles
- **Status:** Complete
- **File:** `lib/widgets/app_filter_chip.dart`
- **Details:** Created reusable FilterChip component with clear states
- **Styling:**
  - **Selected:** Filled orange (accentOrange) + dark text + checkmark icon
  - **Unselected:** Outlined border (borderDefault) + muted text
  - Consistent padding and border radius

### 2.2 ✅ Apply to Songs Status Filters
- **Status:** Complete
- **Files Updated:**
  - `lib/screens/songs/songs_list_screen.dart` - Key filter chips now use AppFilterChip
  - `lib/widgets/tag_cloud_widget.dart` - Tag filters now use AppFilterChip
- **Changes:** Replaced Material FilterChip with AppFilterChip for consistent selected state

### 2.3 ✅ Normalize Home My Library Stat Icons
- **Status:** Complete
- **File:** `lib/screens/home_screen.dart`
- **Change:** Changed Songs stat icon from `accentOrange` to `textSecondary`
  - All three stat icons (Songs, Bands, Setlists) now use same neutral color
  - No icon falsely reads as "selected"

**Phase 2 Exit Criteria:** ✅ All selection states are unambiguous and color-independent

---

## Phase 3: Navigation Legibility ✅ COMPLETE

**Goal:** All destinations are learnable.

### 3.1 ✅ Show Labels on All Bottom-Nav Tabs
- **Status:** Complete
- **File:** `lib/screens/main_shell.dart`
- **Change:** Updated `labelBehavior` from `onlyShowSelected` to `alwaysShow`
- **Result:** All five tabs (Home, Songs, Bands, Setlists, Profile) now display labels

### 3.2 ✅ Add Tooltips and Semantics to Nav Items
- **Status:** Complete
- **File:** `lib/screens/main_shell.dart`
- **Change:** Added Tooltip widgets to each NavigationDestination icon
- **Details:** Labels serve as both visible text and semantic labels (Material NavigationBar exposes these automatically)

**Phase 3 Exit Criteria:** ✅ All primary destinations are identifiable without guessing

---

## Phase 4: Card System Consolidation 🔄 IN PROGRESS

**Goal:** One coherent card language.

### 4.1 ✅ Define 2 Canonical Card Variants
- **Status:** Complete
- **File:** `lib/widgets/app_card.dart`
- **Variants:**
  - **Surface:** Base card with subtle border, no elevation
  - **Raised:** Elevated card with shadow for emphasis
- **Features:**
  - Consistent radius (xlarge = 16px)
  - Proper borders and backgrounds
  - Optional tap callback
  - Optional custom padding

### 4.2 🔄 Migrate Home Cards
- **Status:** Pending
- **Target Files:**
  - `lib/widgets/greeting_card.dart`
  - `lib/widgets/stat_card.dart`
  - `lib/widgets/quick_action_button.dart`
  - `lib/widgets/tool_button.dart`
- **Notes:** These components should wrap AppCard internally or be updated to use AppCard styling

### 4.3 🔄 Migrate Remaining Screens' Cards
- **Status:** Pending
- **Target Screens:**
  - Songs screen
  - Setlist screen
  - Profile screen
  - Bands screen
- **Notes:** Search for bespoke card decorations and consolidate onto AppCard variants

**Phase 4 Dependencies:** Design system tokens ✅ available

---

## Phase 5: Icon Labeling & Accessibility 🔄 PARTIAL

**Goal:** Every interactive control is labeled.

### 5.1 ✅ Create AppIconButton Component
- **Status:** Complete (Pre-existing)
- **File:** `lib/widgets/app_icon_button.dart`
- **Details:** Wraps IconButton with:
  - Required tooltip parameter
  - Semantics(button:, label:) enforcement
  - 48×48 minimum tap target

### 5.2 🔄 Replace Icon-Only Controls
- **Status:** Pending
- **Target Controls:**
  - Song card trailing icons (download)
  - App bar overflow menu
  - Tuner footer icons
  - FABs
- **Approach:** Replace bare IconButton with AppIconButton providing labels

### 5.3 🔄 Verify 48×48 Touch Targets
- **Status:** Pending
- **Action:** Audit icon button sizing across app and update where needed

**Phase 5 Dependencies:** Phase 4 (shared components) - Components are created, pending usage

---

## Phase 6: Copy, Terminology & Verification 📋 PENDING

**Goal:** Remove confusing wording and confirm the whole pass.

### 6.1 📋 Reconcile Labels
- **Status:** Pending
- **Items to Fix:**
  - Profile "My Tags" vs "My Roles" - align section headings
  - Rename ambiguous "Bank" to "Song Bank" or "Library"
  - Align form field labels consistency
  - Ensure nav/action labels are unambiguous

### 6.2 📋 Improve Home Layout
- **Status:** Pending
- **Issues to Address:**
  - Large dead lower third on tall phones
  - Add "Up next" or "Recent" section for value
  - Let content breathe more (larger cards/spacing)

### 6.3 📋 Verification Pass
- **Status:** Pending
- **Checklist:**
  - ✅ Phase 1 findings resolved (primary CTAs visible)
  - ✅ Phase 2 findings resolved (selection states clear)
  - ✅ Phase 3 findings resolved (nav labels visible)
  - 🔄 Phase 4 findings (card consolidation in progress)
  - 🔄 Phase 5 findings (icon labeling pending)
  - 📋 Phase 6 findings (terminology pending)
  - Re-screenshot five reviewed screens
  - Run `flutter analyze` on modified files

---

## Files Created

1. `lib/widgets/primary_action_bar.dart` - Bottom action bar for forms
2. `lib/widgets/app_filter_chip.dart` - Standardized filter chip component
3. `lib/widgets/app_card.dart` - Canonical card variants (surface & raised)

## Files Modified

### Screens
- `lib/screens/setlists/create_setlist_screen.dart` - Added PrimaryActionBar
- `lib/screens/bands/create_band_screen.dart` - Added PrimaryActionBar
- `lib/screens/songs/add_song_screen.dart` - Added PrimaryActionBar
- `lib/screens/songs/songs_list_screen.dart` - Updated filter chips to AppFilterChip
- `lib/screens/home_screen.dart` - Normalized stat icon colors
- `lib/screens/main_shell.dart` - Always show nav labels, added tooltips

### Widgets
- `lib/widgets/tag_cloud_widget.dart` - Updated to use AppFilterChip

---

## Next Steps

### Immediate (High Priority)
1. **Phase 4.2:** Migrate Home cards to AppCard
   - Update greeting_card.dart, stat_card.dart, quick_action_button.dart, tool_button.dart
   - Ensure consistent styling

2. **Phase 4.3:** Migrate remaining screens' cards
   - Songs, Setlist, Profile, Bands screens
   - Search for bespoke card decorations

3. **Phase 5.2:** Replace icon-only controls
   - Song cards: update trailing delete/download icons
   - App bars: update overflow menu icons
   - Tuner: update footer icons
   - FABs: ensure all have labels

### Medium Priority
4. **Phase 6.1:** Reconcile terminology
   - Search for "Bank" references and rename
   - Verify section heading alignment
   - Check form labels consistency

5. **Phase 6.2:** Improve Home layout
   - Add "Recent" or "Up next" section
   - Improve spacing and card sizing

### Final
6. **Phase 6.3:** Verification pass
   - Re-screenshot all affected screens
   - Run `flutter analyze`
   - Confirm all critique findings are resolved

---

## Testing Checklist

- [ ] All form screens show persistent primary action button
- [ ] Filter chips show clear selected/unselected states
- [ ] All bottom nav tabs show labels
- [ ] Stat icons are consistent (no false selection indicators)
- [ ] Cards follow one of two canonical variants
- [ ] Icon buttons have tooltips and semantic labels
- [ ] No code violations from `flutter analyze`
- [ ] All critique findings resolved

---

## Design System References

- **Colors:** `lib/theme/mono_pulse_theme.dart` - MonoPulseColors
- **Spacing:** MonoPulseSpacing (4-point grid)
- **Radius:** MonoPulseRadius (small: 8px through massive: 24px)
- **Elevation:** MonoPulseElevation (shadowLow, shadowMedium, shadowHigh)
- **Typography:** MonoPulseTypography

---

## Collaboration Notes

- AppIconButton was already implemented - repurposed for Phase 5.1
- Design tokens are complete and well-structured
- Migration strategy: Create new components first, then apply across screens
- All changes maintain true-black + orange accent brand identity
