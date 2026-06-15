# UX/UI Critique — FlowGroove (whole app)

**Date:** June 15, 2026
**Reviewed from:** real device screenshots (Home, Songs, Create Setlist, Profile, Tuner) + code
**Stage:** shipping product (v0.13.x), refinement
**Design language:** Mono Pulse — true-black, monochrome + orange accent

---

## Overall impression

The app has a strong, cohesive identity: confident true-black surfaces, a single orange accent used for emphasis, and a clean type hierarchy. The **Tuner is genuinely excellent** — clear primary action, beautiful radial dial, obvious state ("In Tune"). The biggest opportunities are **consistency** (cards, chips, and bottom-nav behave differently screen to screen) and a few **discoverability** gaps where primary actions or selection states aren't obvious. Nothing here is broken; it's polish that will make the app feel professionally finished.

---

## Usability

| Finding | Severity | Recommendation |
|---------|----------|----------------|
| **Create Setlist has no visible "Create/Save" CTA.** The form fills the screen; the primary action appears to live in the top-right "⋯" overflow. Submitting is the whole point of the screen. | 🔴 Critical | Add a persistent primary button ("Create Setlist") pinned to the bottom or in the app bar as a text action. Never bury the primary action in an overflow. |
| **Songs filter chips don't show a clear selected state.** "All / learning / ready / hard" all render in the same orange-tinted style, so the active filter is ambiguous. | 🟡 Moderate | Use one clearly "selected" treatment (filled orange + dark text) vs. "unselected" (outlined, muted). Only one should read as active. |
| **Bottom nav shows a text label only on the active tab; the other four are icon-only.** New users must guess what the music/people/setlist icons mean. | 🟡 Moderate | Show labels on all tabs (Material `NavigationBar` default) or at minimum add tooltips. Discoverability > minimalism for primary nav. |
| **Icon-only actions with no label.** The trailing "download" icon on each song card and the "⋯" overflows have no text or tooltip — meaning is guessable at best. | 🟡 Moderate | Add tooltips/`Semantics` labels (ties to the design-system a11y finding) and consider a label on first use. |
| **Two ways to start the same action on Tuner** (top "Listen & Tune" button *and* the bottom mic FAB). | 🟢 Minor | Keep one primary trigger; make the other a clearly secondary/status element, or merge. |
| **Three rows of chrome above the Songs list** (search, sort, status chips, then Key/BPM + count). | 🟢 Minor | Consider collapsing sort + filters into one row, or making the second filter row appear only when engaged. |

---

## Visual hierarchy

- **What draws the eye first (Home):** the warm orange-tinted greeting card — correct, it's a friendly anchor. Then "My Library" stats. Good top-down flow.
- **Reading flow:** Home reads cleanly top→bottom (Greeting → Library → Quick Actions → Tools). The lower third of the screen is empty on tall phones, making the screen feel top-weighted. Consider letting content breathe more (larger cards / spacing) or surfacing a "Recent" or "Up next" block to fill the dead space with value.
- **Emphasis (My Library stats):** only the "Songs" icon is orange; "Bands" and "Setlists" icons are muted. If that's meant to indicate selection it's misleading (they're all just stats). Make the three stat icons consistent (all accent, or all neutral) so none reads as "active."
- **Tuner:** exemplary — the A4 / "In Tune" readout is unmistakably the focal point, with controls orbiting it. This is the hierarchy bar the rest of the app should reach.

---

## Consistency

| Element | Issue | Recommendation |
|---------|-------|----------------|
| Cards | At least 3–4 card treatments coexist: orange-tinted greeting, borderless filled stat cards, bordered quick-action cards, bordered tool cards. | Define 2 canonical card variants (e.g. `surface` and `surfaceRaised`) and map every card to one. |
| Form fields | On Create Setlist, each field styles its leading icon differently — Name has an inline icon, Date a boxed icon + chevron, Location an inline icon, Description none. | Standardize a single field template (leading icon treatment, label, helper, trailing affordance). |
| Section labels | Profile shows a heading "My Tags" over a card titled "My Roles." | Make the section heading and card title agree. |
| Terminology | Home quick action "Bank" is ambiguous (song bank? canonical library?). | Rename to something explicit ("Song Bank" / "Library"). |
| Chips | Status chips (Songs) vs. segmented toggles (Tuner Auto/Manual) vs. filter buttons (Key/BPM) are visually similar but behave differently. | Differentiate selectable filters, single-select segments, and action buttons visually. |

---

## Accessibility

- **Color contrast:** primary/secondary text passes AA comfortably on black (≈19:1 and ≈8:1). **Watch the muted note-ring letters on the Tuner and `textTertiary` metadata** — around 5–6:1, fine for large text but borderline for small labels; keep them ≥ 4.5:1.
- **Touch targets:** card and FAB targets look ≥ 48px. Audit the smaller icon-only buttons (song-card trailing icon, app-bar "⋯", tuner footer icons) to confirm 48×48 hit areas.
- **Labels for screen readers:** icon-only controls are largely unlabeled (matches the design-system audit — only ~8/268 files use `Semantics`). Add labels/tooltips to every icon button.
- **Selection state not encoded beyond color:** filter chips rely on a color tint alone. Add a check/fill + text-weight change so state isn't color-only.

---

## What works well

- **Strong, consistent brand identity** — true-black + single orange accent reads as premium and is applied with restraint.
- **The Tuner screen** — clear hierarchy, obvious primary action, delightful radial visualization, good use of state ("In Tune").
- **Type hierarchy** — titles, values, and muted metadata are clearly differentiated across screens.
- **Empty states exist** — "No songs added", profile roles prompt — many apps skip these.
- **Song cards pack useful metadata** (BPM + key) without clutter.

---

## Priority recommendations

1. **Surface primary actions (Create Setlist first).** Add a persistent "Create" CTA; never hide the main action in an overflow menu. Sweep all create/edit forms for the same pattern. *(Highest impact on task completion.)*
2. **Fix selection-state clarity on filters and stats.** One unambiguous selected style for chips; make the three Library stat icons consistent so none falsely reads as active.
3. **Make the bottom nav legible.** Always-visible labels (or tooltips) on all five tabs so the icon-only destinations are learnable.
4. **Consolidate the card system.** Collapse the 3–4 card treatments into 2 documented variants and apply consistently — this single change will make the whole app feel more unified.
5. **Label icon-only controls.** Tooltips + `Semantics` on every icon button (download, overflow, tuner footer) — improves both discoverability and accessibility.
6. **Reconcile copy + terminology.** "My Tags"/"My Roles", "Bank", and field labels — small wording fixes that remove confusion.

---

## Suggested execution order

| Step | Scope | Effort | Why here |
|------|-------|--------|----------|
| 1. Persistent primary CTAs | create/edit forms | S | Direct task-completion win, low risk |
| 2. Filter/stat selection states | Songs, Home | S | Removes ambiguity, cheap |
| 3. Bottom-nav labels | shell | S | Learnability for all destinations |
| 4. Card-variant consolidation | app-wide | M | Builds on design-system token work |
| 5. Icon labels + tooltips | app-wide | M | Pairs with a11y Phase 5 in the design-system plan |
| 6. Copy/terminology pass | app-wide | S | Final polish |

Steps 4–5 dovetail with the existing `DESIGN_SYSTEM_REMEDIATION_PLAN.md` (card tokens + accessibility baseline), so sequence them together.
