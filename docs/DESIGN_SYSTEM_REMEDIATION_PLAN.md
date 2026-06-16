# Design System Remediation Plan — Mono Pulse

**Companion to:** `docs/DESIGN_SYSTEM_AUDIT.md`
**Date:** June 15, 2026
**Goal:** Close all 14 audit findings, raising the system score from 72 → ~95.
**Ordering principle:** Foundation first (one source of truth), then enforcement, then sweep. Each phase is independently shippable and non-breaking until the final cleanup.

---

## Phase 0 — Done in audit pass ✅

Already landed, non-breaking:

- `CustomButton` tokenized (`MonoPulseSpacing` / `MonoPulseIcons`) + `tooltip` / `semanticLabel` + button semantics.
- Duplicate opacity tokens (`orangeSubtle15/20/30`) marked `@Deprecated`, aliased to canonical `accentOrange*`.

---

## Phase 1 — Unify the token foundation

*Why first: every later phase references tokens. Collapsing the duplicates now prevents migrating code onto names that are about to be deleted.*

1. **Collapse `AppDimensions` onto MonoPulse tokens.** Re-export `cardBorderRadius → MonoPulseRadius.large`, `gridSpacing → MonoPulseSpacing.sm`, `minTapTarget` stays (it's the only a11y constant). Keep the class as a thin facade so call sites don't churn yet.
2. **Collapse `SectionColorPalette.hexPresets`.** Replace the near-duplicate hex (`EF5350`, `66BB6A`…) with references to `MonoPulseColors.section*`. Delete the "similar" comments.
3. **Finish the opacity-token consolidation.** Migrate any callers off the deprecated `orangeSubtle*` names (audit found zero today, so this is a guard for new code), then schedule deletion for Phase 6.
4. **Standardize opacity naming.** Rename remaining ad-hoc names (`accentOrangeSubtle`, `errorSubtle5/20/30`) to the `token{NN}` convention. Add aliases, don't hard-rename.

**Exit:** one definition per value; `grep` shows no duplicated hex/dimension constants.

---

## Phase 2 — Fix cross-platform typography

*Why here: independent of tokens, but should precede the type sweep in Phase 4 so raw `fontSize`/`TextStyle` get migrated onto a typeface that actually renders.*

1. **Bundle Inter.** Add the Inter font files under `assets/fonts/` and declare them in `pubspec.yaml` `fonts:` (regular/medium/semibold/bold), or add `google_fonts`.
2. **Point the type scale at it.** Set `MonoPulseTypography.fontFamily` / `fontFamilyDisplay` to the bundled family; keep `.SF Pro` only as an explicit Apple-platform override if desired.
3. **Verify on all targets.** Build web + Android + iOS, screenshot a text-heavy screen, confirm identical typeface.

**Exit:** one typeface renders on iOS, Android, and web.

---

## Phase 3 — Define interaction-state & functional-palette tokens

*Why here: Phase 5 (a11y) and Phase 4 (sweeps) both consume these; defining them once keeps custom `GestureDetector` surfaces consistent with Material.*

1. **Add state overlays** to `MonoPulseColors`: `stateHover` (white @ ~4%), `stateFocus` (accentOrange @ ~12%), `statePressed`, `stateDisabled`. Wire them into the theme's `WidgetStateProperty` overlays.
2. **Document the functional palette.** Add a doc comment block declaring `info`/`warning`/`success*`, role colors, match-grade colors, and the 14 section colors as intentional exceptions to "monochrome + orange."
3. **Resolve the product-name mismatch** ("Mono Pulse" vs "FlowGroove") in docs/banner — pick one.

**Exit:** hover/focus/pressed/disabled are tokens; semantic colors are documented, not "drift."

---

## Phase 4 — Sweep raw values onto tokens

*Why here: foundation, typeface, and state tokens now all exist, so the sweep migrates onto final names.*

1. **Spacing:** convert the 97 raw `EdgeInsets` → `MonoPulseSpacing`. Start with shared `lib/widgets/`, then screens.
2. **Radius:** convert the 20 raw `BorderRadius.circular(n)` → `MonoPulseRadius`.
3. **Typography:** convert 61 raw `fontSize` / collapse 154 inline `TextStyle` → `MonoPulseTypography` styles (`.copyWith` for one-offs).
4. **Colors:** replace the ~23 stray `Colors.*` and 2 raw `Color(0x…)` (incl. `central_dial.dart`) with `MonoPulseColors`.

**Exit:** `grep` for raw spacing/radius/fontSize/hex in `lib/` trends to near-zero.

---

## Phase 5 — Accessibility baseline

*Why here: components are now consistent, so labels/tooltips are the remaining gap.*

1. **Label icon-only controls.** Wrap the 51 `IconButton`s and 60 custom tap targets with `Semantics(button: true, label:)` + `Tooltip` (reuse the `CustomButton` pattern; consider a shared `AppIconButton`).
2. **Label progress/status.** Give `LoadingIndicator` a `semanticsLabel`; ensure `EmptyState` icon is `excludeSemantics` with a labeled message.
3. **Enforce tap targets.** Audit custom `GestureDetector` regions against `minTapTarget` (48×48); wrap undersized ones.
4. **Token the disabled text exemption.** Confirm `textDisabled` is only ever used on disabled controls (exempt from contrast), never live text.

**Exit:** every interactive control is announced; tap targets ≥48px.

---

## Phase 6 — Enforce & document

*Why last: lock in the gains so the system doesn't regress.*

1. **Lint rules.** Add `custom_lint` rules (or CI grep gates) flagging: raw `Color(0x…)`, `Colors.*`, raw `fontSize`, raw `BorderRadius.circular(n)`, and `IconButton` without a tooltip/label.
2. **Analyzer in CI.** Wire `flutter analyze` as a required gate (the audit noted it wasn't run).
3. **Delete deprecated aliases.** Remove `orangeSubtle*` and any other temporary aliases once callers are migrated.
4. **Component docs.** Document the shared component library (variants/states/a11y) per the audit's completeness table — start with `CustomButton`, `CustomTextField`, `EmptyState`, the card family.

**Exit:** new raw values fail CI; deprecated tokens gone; components documented.

---

## Suggested sequencing

| Phase | Risk | Breaking? | Rough effort |
|-------|------|-----------|--------------|
| 1 Token foundation | Low | No (aliases) | S |
| 2 Typography | Low | No | S |
| 3 State + palette tokens | Low | No | S |
| 4 Raw-value sweep | Med | No | L (mechanical, do in chunks) |
| 5 Accessibility | Med | No | M |
| 6 Enforce + cleanup | Low | Yes (alias deletion) | S |

Phases 1–3 can land in parallel; Phase 4 depends on 1–3; Phase 5 depends on 4 for consistency; Phase 6 is the final lock-in.
