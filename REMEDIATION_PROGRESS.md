# Design System Remediation — Progress Summary

**Date:** June 15, 2026  
**Status:** Phases 1–3 complete. Phase 4 in progress.

---

## Completed ✅

### Phase 1: Unify Token Foundation
- ✅ Standardized opacity naming: `error5/20/30`, `successGreen5`, `warning5`, `info5` (canonical)
- ✅ Added deprecated aliases for backward compatibility (`accentOrangeSubtle` → `accentOrange10`, etc.)
- ✅ Collapsed `AppDimensions` onto MonoPulse tokens via facade (calls → `MonoPulseSpacing.sm`, `MonoPulseRadius.large`)
- ✅ Cleaned `SectionColorPalette.hexPresets` comments (removed "similar" drift markers)
- ✅ **Exit criteria met:** One definition per value; duplicate hex/dimension constants resolved

### Phase 2: Fix Cross-Platform Typography
- ✅ Added `google_fonts: ^7.0.0` to `pubspec.yaml`
- ✅ Updated `MonoPulseTypography` to use Inter via `GoogleFonts.inter()`
- ✅ Converted all TextStyle statics to getters (to support dynamic fontFamily)
- ✅ **Exit criteria met:** One typeface (Inter) renders cross-platform (iOS, Android, web)

### Phase 3: Define Interaction-State & Functional-Palette Tokens
- ✅ Added state overlay tokens to `MonoPulseColors`:
  - `stateHover` (white @ 4%)
  - `stateFocus` (orange @ 12%)
  - `statePressed` (orange @ 16%)
  - `stateDisabled` (disabled @ 30%)
- ✅ Wired overlays into `ElevatedButton` and `OutlinedButton` themes via `WidgetStateProperty`
- ✅ Documented functional palette (section colors as intentional exceptions to monochrome + orange rule)
- ✅ **Exit criteria met:** Hover/focus/pressed/disabled are tokenized; semantic colors documented

---

## In Progress — Phase 4: Sweep Raw Values Onto Tokens

**Scope identified:**
- ~59 raw `EdgeInsets` with numeric literals → `MonoPulseSpacing`
- ~20 raw `BorderRadius.circular(n)` → `MonoPulseRadius`
- ~1100+ `Colors.*` refs across 109 files → `MonoPulseColors`
- ~61 raw `fontSize` / 154 inline `TextStyle` → `MonoPulseTypography`

**Strategy:** Prioritize high-impact shared components first (CustomButton, CustomTextField, Card families, common padding patterns).

**Files to target next:**
1. `lib/widgets/custom_button.dart` — button foundation
2. `lib/widgets/custom_text_field.dart` — input foundation
3. `lib/widgets/custom_app_bar.dart` — app bar consistency
4. `lib/widgets/error_banner.dart` — common feedback
5. High-frequency containers (cards, padding, spacing)

---

## Not Yet Started — Phases 5–6

| Phase | Goal | Effort |
|-------|------|--------|
| 5 | Label icon-only controls (111 IconButtons/custom tap targets); audit tap targets ≥48px | M |
| 6 | Add lint rules; wire flutter analyze to CI; delete deprecated aliases; document components | S |

---

## Notes

- Deprecated aliases allow gradual migration without forcing a flag day
- Foundation phases (1–3) are non-breaking; Phase 4 sweep is safe but mechanical; Phase 5–6 enforce & lock in gains
- Google Fonts adds ~2MB to bundle; consider lazy-loading or alternatives if needed later
