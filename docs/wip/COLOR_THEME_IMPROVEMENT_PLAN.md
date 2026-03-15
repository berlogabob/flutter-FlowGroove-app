# Color Theme Improvement Plan

**Created:** 2026-03-15  
**Status:** ✅ **COMPLETE**  
**Priority:** High  

---

## Goal

Flatten and simplify color theming. Fix errors, doublings, and hardcoded values. Make color scheme consistent and easy to use and maintain.

---

## 1. Current State Analysis

### ✅ Strengths
- Well-structured `MonoPulseTheme` system in `/lib/theme/mono_pulse_theme.dart`
- Comprehensive color palette with semantic naming (surfaces, text, accents, roles)
- Dark-only theme following Material 3 conventions
- Good typography and spacing systems

### ❌ Issues Found

| Issue | Location | Count |
|-------|----------|-------|
| **Hardcoded Colors** | `unified_item_card.dart` | 3 instances |
| **Material Colors** | Various screens/services | 18 instances |
| **Opacity Variants** | Scattered `withValues()` calls | 47 instances |
| **Duplicate Definitions** | Section colors in 2 places | 2 files |

---

## 2. Hardcoded Colors to Fix

### `lib/widgets/unified_item/unified_item_card.dart` (Lines 77-84)
```dart
// ❌ Current - Hardcoded
backgroundColor: isShared ? const Color(0xFFFFE0B2) : const Color(0xFF1A1A1A),
color: isShared ? const Color(0xFFFF9800) : MonoPulseColors.accentOrange,

// ✅ Should use:
backgroundColor: isShared ? MonoPulseColors.warningSubtle : MonoPulseColors.surfaceRaised,
color: isShared ? MonoPulseColors.warning : MonoPulseColors.accentOrange,
```

### Other Material Color violations:
- `lib/screens/bands/song_picker_screen.dart`: `Colors.orange`, `Colors.green`, `Colors.red`
- `lib/widgets/matching/song_match_dialog.dart`: `Colors.orange` (3x)
- `lib/services/csv/song_csv_service.dart`: `Colors.blue`, `Colors.green`
- `lib/screens/songs/components/spotify_search_section.dart`: `Colors.orange`, `Colors.red`
- `lib/screens/songs/components/musicbrainz_search_section.dart`: `Colors.red`

---

## 3. Implementation Plan

### Phase 1: Add Missing Color Variants
**File:** `lib/theme/mono_pulse_theme.dart`  
**Time:** 15 min

Add to `MonoPulseColors`:
```dart
// Shared/Copy state colors (new)
static const Color sharedBackground = Color(0xFFFFE0B2);
static const Color sharedIcon = Color(0xFFFF9800);

// Additional opacity variants for consistency
static const Color accentOrange15 = Color(0x26FF5E00); // 15% opacity
static const Color accentOrange30 = Color(0x4DFF5E00); // 30% opacity
```

### Phase 2: Fix Hardcoded Colors
**Time:** 30 min

Files to update:
1. `lib/widgets/unified_item/unified_item_card.dart`
2. `lib/screens/bands/song_picker_screen.dart`
3. `lib/widgets/matching/song_match_dialog.dart`
4. `lib/services/csv/song_csv_service.dart`
5. `lib/screens/songs/components/spotify_search_section.dart`
6. `lib/screens/songs/components/musicbrainz_search_section.dart`

### Phase 3: Consolidate Opacity Variants
**Time:** 20 min

Currently 47 scattered `withValues()` calls. Add pre-defined variants:
```dart
// In MonoPulseColors
static const Color accentOrange20 = Color(0x33FF5E00); // 20% opacity
static const Color borderSubtle30 = Color(0x4D222222); // 30% opacity
```

### Phase 4: Documentation & Guidelines
**Time:** 10 min

Add usage guidelines to `color_theme.md`:
```markdown
## Color Usage Guidelines
- ✅ ALWAYS use `MonoPulseColors.*` 
- ❌ NEVER use `Color(0xFF...)` directly
- ❌ NEVER use `Colors.*` from Material
- Use semantic names: `textSecondary` not `grey400`
```

---

## 4. File Structure After Cleanup

```
lib/theme/
└── mono_pulse_theme.dart    # Single source of truth
    ├── MonoPulseColors      # All color definitions
    ├── MonoPulseTypography  # Text styles
    ├── MonoPulseSpacing     # 4pt grid system
    ├── MonoPulseRadius      # Border radius
    ├── MonoPulseElevation   # Shadows
    ├── MonoPulseAnimation   # Durations & curves
    └── MonoPulseTheme       # ThemeData configuration
```

---

## 5. Checklist

- [x] Phase 1: Add missing color variants to `MonoPulseColors`
- [x] Phase 2: Fix all hardcoded colors (6 files)
- [x] Phase 3: Add opacity variants and update `withValues()` calls
- [x] Phase 4: Update documentation with usage guidelines
- [x] Run `flutter analyze` to verify no errors
- [x] Test app to ensure visual consistency

**All tasks completed!** See `COLOR_THEME_CLEANUP_COMPLETE.md` for detailed report.

---

## 6. Related Files

- `/lib/theme/mono_pulse_theme.dart` - Main theme file
- `/lib/screens/songs/components/song_constructor/core/theme/app_colors.dart` - Section colors (uses MonoPulse)
- `/lib/screens/songs/components/song_constructor/core/theme/section_color_manager.dart` - Color manager

---

## Notes

- Keep the dark-only theme approach
- Maintain semantic naming conventions
- Ensure all new colors work on dark backgrounds
- Test on both mobile and web versions
