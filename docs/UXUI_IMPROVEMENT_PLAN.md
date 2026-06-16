# UX/UI Improvement Plan — FlowGroove

**Source:** `docs/UXUI_CRITIQUE.md`
**Date:** June 15, 2026
**Ordering principle:** highest task-completion impact and lowest risk first; shared-component work placed so later phases build on it. Phases are independently shippable.

Legend — Effort: S (≤½ day) · M (1–2 days) · L (multi-day). Each task lists **Done when** (acceptance criteria).

---

## Phase 1 — Surface primary actions (Critical)

*Goal: no primary action is ever hidden. Fixes the one 🔴 issue.*

1.1 **Build a reusable `PrimaryActionBar`** (pinned bottom bar hosting a full-width `CustomButton`). — S
  - Done when: a single widget renders a safe-area-aware bottom CTA usable by any form screen.
1.2 **Add a persistent "Create Setlist" CTA** to Create Setlist; remove the create action from the "⋯" overflow. — S
  - Done when: Create is visible without opening any menu; disabled until required fields valid.
1.3 **Sweep all create/edit forms** (Create Band, Add Song, Create Setlist, Edit Profile) for hidden primary actions; apply `PrimaryActionBar`. — M
  - Done when: every form's primary action is visible on screen; overflow holds only secondary actions.

**Phase exit:** every create/edit flow has an on-screen primary CTA.

---

## Phase 2 — Selection-state clarity (Moderate)

*Goal: a user can always tell what's selected.*

2.1 **Define selected vs. unselected chip styles** (selected = filled accent + dark text + check; unselected = outlined + muted). Reuse the Phase 3 state tokens from the design-system plan if available. — S
  - Done when: one unambiguous selected treatment exists as a shared `FilterChip` style.
2.2 **Apply to Songs status filters** ("All / learning / ready / hard") so exactly one reads active. — S
  - Done when: tapping a chip visibly changes only its state; only the active chip is filled.
2.3 **Normalize Home "My Library" stat icons** (all neutral, or all accent) so none falsely reads as selected. — S
  - Done when: the three stat cards use identical icon emphasis.

**Phase exit:** no element communicates state through color alone or ambiguously.

---

## Phase 3 — Navigation legibility (Moderate)

*Goal: all destinations are learnable.*

3.1 **Show labels on all bottom-nav tabs** (migrate to Material `NavigationBar` with `labelBehavior: alwaysShow`, or add labels to the current bar). — S
  - Done when: all five tabs show a text label, not just the active one.
3.2 **Add tooltips/Semantics to nav items** as a fallback for icon recognition. — S
  - Done when: each tab exposes an accessible label.

**Phase exit:** every primary destination is identifiable without guessing.

---

## Phase 4 — Card system consolidation (Moderate)

*Goal: one coherent card language. Builds on design-system token work.*

4.1 **Define 2 canonical card variants** (e.g. `AppCard.surface` and `AppCard.raised`) mapping to MonoPulse tokens; document when to use each. — M
  - Done when: a shared card widget exposes both variants with consistent radius/border/elevation.
4.2 **Migrate Home cards** (greeting, stat, quick-action, tool) onto the two variants. — M
  - Done when: Home uses only the two canonical variants.
4.3 **Migrate remaining screens'** ad-hoc cards (Songs, Setlist, Profile, Bands) onto the variants. — M
  - Done when: `grep` finds no bespoke card decorations outside `AppCard`.

**Phase exit:** the whole app draws cards from one of two documented variants.

---

## Phase 5 — Icon labeling & accessibility (Moderate)

*Goal: every interactive control is labeled. Pairs with design-system Phase 5.*

5.1 **Create a shared `AppIconButton`** wrapping `IconButton` with required `tooltip` + `Semantics(button:, label:)`. — S
  - Done when: a single component enforces a label on every icon button.
5.2 **Replace icon-only controls** (song-card trailing action, app-bar "⋯", tuner footer, FABs) with labeled equivalents. — M
  - Done when: no bare `IconButton`/`GestureDetector` action lacks a label.
5.3 **Verify 48×48 touch targets** on all icon controls. — S
  - Done when: every interactive icon meets the minimum hit area.

**Phase exit:** all icon-only actions are labeled and adequately sized.

---

## Phase 6 — Copy, terminology & verification (Minor + sign-off)

*Goal: remove confusing wording and confirm the whole pass.*

6.1 **Reconcile labels:** Profile "My Tags" vs "My Roles"; rename ambiguous "Bank"; align form field labels. — S
  - Done when: section headings match their card titles; no ambiguous nav/action labels remain.
6.2 **Tighten Home empty space / add value block** (optional "Up next" / "Recent" section) so tall screens aren't top-weighted. — M
  - Done when: Home no longer has a large dead lower third (or it's intentional with a value block).
6.3 **Verification pass:** re-screenshot the five reviewed screens + the newly touched forms; confirm each critique finding is resolved; run `flutter analyze`. — M
  - Done when: a before/after check confirms all 🔴/🟡 findings closed; analyzer clean for touched files.

**Phase exit:** critique findings closed and visually verified.

---

## Sequencing & dependencies

| Phase | Depends on | Risk | Effort |
|-------|-----------|------|--------|
| 1 Primary CTAs | — | Low | S–M |
| 2 Selection states | (state tokens, optional) | Low | S |
| 3 Nav labels | — | Low | S |
| 4 Card consolidation | design-system tokens | Med | L |
| 5 Icon labels & a11y | 4 (shared components) | Med | M |
| 6 Copy + verification | 1–5 | Low | M |

Phases 1–3 are independent and can ship in parallel. Phase 4 should precede Phase 5 (shared components land first). Phase 6 closes out. Phases 4–5 deliberately overlap the card-token and accessibility phases in `DESIGN_SYSTEM_REMEDIATION_PLAN.md` — run them together to avoid double work.
