# Design System Audit — Mono Pulse

**Date:** June 15, 2026
**App version:** 0.13.4+197
**System:** `MonoPulse` (dark-only) — `lib/theme/mono_pulse_theme.dart`
**Scope:** 267 Dart files in `lib/`, token definitions, ~30 shared widgets, accessibility, cross-platform typography
**Method:** Static source review + token-adoption counts + WCAG contrast calculation (analyzer not run in sandbox)

---

## Summary

**Components reviewed:** ~30 shared widgets | **Issues found:** 14 | **Score: 72 / 100**

Mono Pulse is a genuinely well-conceived system: a clear philosophy (strict monochrome + one orange accent), a 4-point grid, a full type scale, motion and elevation tokens, and a single `ThemeData` source. Color-token adoption is excellent. The score is held back by three things: a second, parallel token set (`SectionColorPalette` / `AppDimensions`) that duplicates the core, weak accessibility coverage, and a documented typeface that does not actually render on Android or web.

What's strong:

- Single source of truth for theming via `MonoPulseTheme.theme`, wired into Material 3 `ColorScheme`, component themes, and `TextTheme`.
- Heavy, consistent token usage: `MonoPulseTypography` in 73 files, `MonoPulseSpacing` in 68, `MonoPulseRadius` in 53.
- Only ~23 hardcoded Material colors and 2 raw hex values across the whole app — color discipline is rare and impressive at this size.
- `withOpacity` (deprecated) fully migrated to `withValues` (74 uses, 0 legacy).
- Shared components already cover the common cases: `CustomButton` (4 variants × 3 sizes + loading), `CustomTextField`, `EmptyState`, `LoadingIndicator`, card family.

---

## Naming Consistency

| Issue | Where | Recommendation |
|-------|-------|----------------|
| Duplicate opacity tokens — same value under two names | `accentOrange15/20/30` == `orangeSubtle15/20/30` (identical `0x26/33/4D FF5E00`) | Keep one family. Deprecate `orangeSubtle*` in favor of `accentOrange*`; alias during migration. |
| Three overlapping orange-opacity naming schemes | `accentOrangeSubtle`, `orangeSubtle5`, `accentOrange15` | Standardize on `accentOrange{NN}` where NN = opacity %. Drop the ad-hoc `Subtle` suffix. |
| Parallel color system | `SectionColorPalette.hexPresets` defines `EF5350`, `66BB6A`… described in comments as "section1 similar" | Reference `MonoPulseColors.section*` directly instead of near-duplicate hex. |
| Parallel dimension system | `AppDimensions.cardBorderRadius = 12.0` duplicates `MonoPulseRadius.large`; `gridSpacing = 8.0` duplicates `MonoPulseSpacing.sm` | Re-export from MonoPulse tokens, don't redefine raw doubles. |
| Semantic colors break the "monochrome + orange" rule undocumented | `info` (blue), `warning` (amber), `successGreen`, role + match colors | Legitimate, but document them as an explicit "functional palette" so they aren't seen as drift. |
| Product name mismatch | Theme = "Mono Pulse"; `AUDIT.md` / version banner = "FlowGroove" | Pick one product name in docs to avoid confusion. |

---

## Token Coverage

| Category | Defined | Hardcoded values found in `lib/` | Verdict |
|----------|---------|----------------------------------|---------|
| Colors | ✅ full (`MonoPulseColors`) | ~23 Material `Colors.*` + 2 raw `Color(0x…)` (`central_dial.dart`) | Strong |
| Spacing | ✅ `MonoPulseSpacing` (xxs–massive) | 97 `EdgeInsets` with raw numbers | Partial |
| Radius | ✅ `MonoPulseRadius` (8–24) | 20 raw `BorderRadius.circular(n)` | Partial |
| Typography | ✅ full scale (display→label) | 61 raw `fontSize:`, 154 inline `TextStyle(` | Partial |
| Elevation/Shadow | ✅ `MonoPulseElevation` | low usage | Underused |
| Motion | ✅ `MonoPulseAnimation` | only 17 files | Underused |
| Icon sizing | ✅ `MonoPulseIcons` | `CustomButton` redefines 16/18/20 locally | Partial |

The pattern is clear: **colors are tokenized, but spacing, radius, and type still leak raw numbers.** Even `CustomButton` — the flagship shared component — hardcodes `EdgeInsets.symmetric(horizontal: 24, vertical: 12)` and icon sizes instead of using the tokens that already exist with those exact values.

---

## Accessibility (WCAG 2.1 AA)

Contrast (calculated against true black `#000000`, the scaffold background):

| Token | Ratio vs black | AA normal text (4.5:1) | AA large/UI (3:1) |
|-------|----------------|------------------------|-------------------|
| `textPrimary` #F5F5F5 | 19.26:1 | ✅ | ✅ |
| `textSecondary` #A0A0A5 | 8.07:1 | ✅ | ✅ |
| `textTertiary` #8A8A8F | 6.11:1 | ✅ | ✅ |
| `accentOrange` #FF5E00 | 6.85:1 | ✅ | ✅ |
| `textDisabled` #555555 | 2.82:1 | ❌ (disabled is exempt, OK) | ⚠️ |

Color contrast is in good shape. The real gap is **semantic accessibility**:

- **Semantics coverage is thin:** only 4 of 267 files use `Semantics` / `semanticLabel`, against 51 `IconButton`s and 60 `GestureDetector`/`InkWell` tap handlers. Icon-only controls and custom tap targets will be unlabeled or unannounced to screen readers.
- **Tooltips** appear in only 23 files — many icon-only buttons lack hover/long-press labels.
- **Tap targets:** several widgets correctly enforce `minHeight: 48`, but this isn't systematic. Custom `GestureDetector` regions should be audited against the 48×48 minimum (already a constant: `AppDimensions.minTapTarget`).
- **Section/match colors** on dark with auto black text (`getContrastingTextColor`) are fine, but yellow/lime swatches with white text would fail — the luminance switch handles this; keep it.

---

## Component Completeness

| Component | States | Variants | Sizes | A11y | Docs | Score |
|-----------|--------|----------|-------|------|------|-------|
| CustomButton | default/loading/disabled ✅, hover/focus/pressed ⚠️ (Material default only) | ✅ 4 | ✅ 3 | ❌ no Semantics/tooltip | ⚠️ dartdoc only | 7/10 |
| CustomTextField | default/focus/error ✅, disabled ⚠️ | ⚠️ implicit | — | ⚠️ relies on label | ⚠️ | 7/10 |
| EmptyState | default ✅ | — | hardcoded `iconSize: 80` | ⚠️ | ⚠️ | 6/10 |
| Card family (song/band/setlist/stat) | default/tap ✅ | ✅ | — | ⚠️ | ❌ | 6/10 |
| LoadingIndicator | default ✅ | — | — | ❌ no label | ❌ | 5/10 |
| FAB variants | default ✅ | ✅ | — | ⚠️ | ❌ | 6/10 |

States that exist via Material defaults (hover/focus/pressed) aren't expressed as tokens, so they're inconsistent across custom `GestureDetector`-based widgets that bypass Material ink.

---

## Priority Actions

1. **Consolidate the two token systems.** Make `SectionColorPalette` and `AppDimensions` re-export `MonoPulseColors`/`MonoPulseRadius`/`MonoPulseSpacing` instead of redefining values. Deprecate duplicate opacity tokens (`orangeSubtle*` → `accentOrange*`). One source of truth, fewer drift vectors. *(Highest leverage, low risk.)*

2. **Fix cross-platform typography.** `fontFamily: '.SF Pro Text'` resolves only on Apple platforms; Android and web silently fall back to Roboto, so the documented "Inter / SF Pro" identity isn't what most users see. Bundle **Inter** (declare in `pubspec.yaml` `fonts:`) or use `google_fonts`, and set it as the family — guaranteeing one typeface everywhere.

3. **Add an accessibility baseline.** Wrap icon-only `IconButton`s and custom tap targets with `Semantics(label:, button: true)` + `Tooltip`; give `LoadingIndicator` a `semanticsLabel`. Add a lint/CI check for icon buttons without labels. Target: every interactive icon announced.

4. **Tokenize the remaining raw values.** Sweep the 97 raw `EdgeInsets`, 20 raw `BorderRadius`, and 61 raw `fontSize` onto existing tokens — starting with shared widgets (`CustomButton`, `EmptyState`). Add a `custom_lint` rule to flag new raw values.

5. **Express interaction states as tokens.** Define hover/focus/pressed/disabled overlays (e.g. `stateHover = white @ 4%`, `stateFocus = accentOrange @ 12%`) and apply them consistently to both Material and custom tap surfaces so `GestureDetector` widgets match buttons.

6. **Document the functional palette.** The semantic (`info`/`warning`/`success`), role, match, and 14 section colors are valid but undocumented exceptions to "monochrome + orange." Write them up so they read as system, not drift.

---

## Quick wins implemented in this pass

See `lib/widgets/custom_button.dart` and `lib/theme/mono_pulse_theme.dart`:

- `CustomButton` now uses `MonoPulseSpacing` / `MonoPulseIcons` tokens instead of hardcoded paddings and icon sizes (values unchanged), and accepts an optional `tooltip` + `semanticLabel` and exposes itself as a button to screen readers.
- Duplicate opacity tokens are marked `@Deprecated` with the canonical `accentOrange*` aliases called out, so migrations can begin without breaking callers.

These are non-breaking; existing values are preserved exactly.
