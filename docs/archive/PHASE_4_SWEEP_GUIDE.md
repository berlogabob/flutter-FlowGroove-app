# Phase 4: Raw Values → Token Sweep Guide

**Goal:** Convert raw numeric values to MonoPulse tokens (spacing, radius, colors).  
**Non-breaking:** All changes are safe; no breaking API changes.

---

## Quick Token Mappings

### Spacing (8px = sm, 12px = md, 16px = lg, 20px = xl, 24px = xxl, 32px = xxxl, 48px = huge)
```dart
// Raw → Token
8.0, 8  → MonoPulseSpacing.sm
12.0, 12 → MonoPulseSpacing.md
16.0, 16 → MonoPulseSpacing.lg
20.0, 20 → MonoPulseSpacing.xl
24.0, 24 → MonoPulseSpacing.xxl
32.0, 32 → MonoPulseSpacing.xxxl
```

### Radius (8px = small, 10px = medium, 12px = large, 16px = xlarge, 20px = huge, 24px = massive)
```dart
// Raw → Token
8.0, 8  → MonoPulseRadius.small
10.0, 10 → MonoPulseRadius.medium
12.0, 12 → MonoPulseRadius.large
16.0, 16 → MonoPulseRadius.xlarge
20.0, 20 → MonoPulseRadius.huge
24.0, 24 → MonoPulseRadius.massive
```

### Colors
Replace `Colors.red`, `Colors.green`, etc. with `MonoPulseColors.*`. Check context for closest match:
- `Colors.white` → `MonoPulseColors.white`
- `Colors.black` → `MonoPulseColors.black`
- `Colors.grey[X]` → `MonoPulseColors.textSecondary` / `textTertiary` / etc.

---

## High-Impact Foundation Files (Start Here)

### 1. `lib/widgets/custom_button.dart`
- [ ] Line 214: `18` → `MonoPulseIcons.sizeMedium` (or add `sizeButtonMedium` token)
- [ ] Line 182: `SizedBox(width: 8)` → `SizedBox(width: MonoPulseSpacing.sm)`

### 2. `lib/widgets/custom_text_field.dart`
- [ ] Audit padding in InputDecorationTheme overrides
- [ ] Tokenize any raw fontSize in error/hint text styles

### 3. `lib/widgets/custom_app_bar.dart`
- [ ] Padding/height constants → tokens
- [ ] Border radius on any shaped elements

### 4. `lib/widgets/empty_state.dart`
- [ ] Icon size, spacing, padding

### 5. `lib/widgets/error_banner.dart`
- [ ] Spacing, padding, icon sizes

### 6. `lib/widgets/match_score_badge.dart`, `song_bpm_badge.dart`, `song_attribution_badge.dart`
- [ ] Badges are high-frequency; tokenizing them unlocks many downstream benefits

---

## Files with High Color Counts

Sort by `Colors.*` usage (from grep output above):
1. `tuner_screen.dart` — 36 occurrences
2. `tempo_change_dialog.dart` — 32
3. `central_tempo_circle.dart` — 31
4. `bpm_controls_widget.dart` — 21

Focus on swapping `Colors.white`, `Colors.grey`, etc. to MonoPulse equivalents.

---

## Mechanical Replacements (Sed-Safe)

In your editor's find-and-replace:

```
Colors.white              → MonoPulseColors.white
Colors.black              → MonoPulseColors.black
Colors.transparent        → MonoPulseColors.transparent
Colors.red                → MonoPulseColors.error
Colors.green              → MonoPulseColors.successGreen
Colors.grey               → MonoPulseColors.textSecondary (pick appropriate shade)
```

---

## Testing the Sweep

After each file:
1. `flutter analyze` — catch import/usage errors
2. Visual check — colors/spacing look right on emulator or web
3. Git diff — confirm only whitespace/token changes, no logic changes

---

## Completion Checklist

- [ ] All EdgeInsets use `MonoPulseSpacing.*`
- [ ] All BorderRadius use `MonoPulseRadius.*`
- [ ] No raw `Colors.*` (except in theme definitions)
- [ ] No raw `Color(0x...)` literals (except documented exceptions)
- [ ] No raw fontSize values in text styles (use MonoPulseTypography)
- [ ] `grep -r "SizedBox(width: [0-9]" lib/` returns only named constants or tokens
