# FlowGroove beta UX/UI audit

**Date:** 2026-07-14 · **Build:** 0.15.3+335 · **Source:** 105 screenshots in `screenshots/` (see `screenshots/INDEX.md`), captured on a real Android device (1260×2800, dark theme).
**Priority lens:** what would confuse or lose a new beta user first.
**Method:** Nielsen 10-heuristics evaluation (0–4 severity), Google HEART analysis (goals → signals → metrics to instrument), Fitts's Law target-geometry pass, plus a beta-launch prioritization (P0/P1/P2).

---

## Executive summary

1. **The back button is broken on two entry paths** — leaving the Tuner or the Join Band screen exits the app to the launcher. For a beta user this reads as a crash, and Join Band is literally the first screen an invited bandmate sees.
2. **Users without a display name render as blank UI** — a blank member row, an empty chip on the New Rehearsal form, a raw email elsewhere. Three different fallbacks for the same missing data, one of them "nothing at all".
3. **The app's own numbers disagree** — a setlist card says "6 songs", opening it shows 5. Trust in a band-coordination app dies on exactly this kind of mismatch.
4. **The Key filter cannot find real songs** — the library contains `Ab` and `em` (minor) keys, but the filter offers only 12 sharp-major chips. Filtering silently drops songs the user knows they have.
5. **Global menu pollution and naming drift** — every screen's ⋮ menu ends with Keep screen on / Profile / Sign out; "Practice mode" opens a screen titled "Metronome"; "Song Bank" is just the Songs tab under another name; band detail greets you with "Hello, Teplo!" and calls band content "My Library". Individually small, together they make the app feel unfinished in the first ten minutes.

The foundation is good: empty states have friendly, purposeful copy ("Propose a time and let the band vote"), the invite QR screen is clean, PDF export options are well-explained, tag chips show counts. Most fixes below are cuts and renames, not redesigns.

---

## P0 — beta blockers

| # | Finding | Evidence | Fix |
|---|---------|----------|-----|
| P0-1 ✅ fixed (PR #101, device-verified) | **Back from Tuner exits the app** to the Android launcher instead of returning Home. | `85_home__returned-from-tuner.png` (launcher), `86_home__relaunched-after-tuner.png` | Tuner must be a pushed route on the root navigator; intercept system back. |
| P0-2 ✅ fixed (PR #101, device-verified incl. cold deep link) | **Back from Join Band exits the app.** This is the landing screen of every invite deep link — an invited user's first impression. | `63_home__relaunched-after-join.png` | Same back-stack fix; when opened cold from a deep link, back should land on Home, not the launcher. |
| P0-3 ◐ unconfirmed; related Stream.empty hang fixed in PR #101 | **[UNCONFIRMED after re-review]** "Blank screen after closing a popup menu" — the capture agent's INDEX notes claimed it, but the saved screenshots `74`/`80` actually show fully rendered screens; no photographic evidence exists and no code path was found that flips these providers to loading on menu dismissal. Needs a live device repro before any fix. **Related real defect found during diagnosis:** `setlistsProvider` returns `const Stream.empty()` while auth is loading (`lib/providers/data/data_providers.dart:155`) — a stream that never emits, so Setlists can hang in a loading state indefinitely on auth re-emission; sibling songs/bands providers return `Stream.value([])`. One-line fix. | `74_setlists__card-menu-closed.png`, `80_profile__menu-closed.png` | Align `setlistsProvider` loading branch with siblings; re-probe menu-close on device when reconnected. |
| P0-4 ✅ fixed (PR #101) | **Setlist song count mismatch**: card says "6 songs", the opened setlist shows "Songs (5)". | `68_setlists__list.png` vs `69_setlist-detail__main.png` | Count from the same source the editor renders (probably a deleted/unresolvable song still counted). |
| P0-5 ✅ fixed (PR #101, memberLabel util + tests) | **Members with no display name render as blank UI.** About-band shows a nameless row with "?" avatar; New Rehearsal shows a completely **empty chip**; rehearsal detail falls back to raw email. Three screens, three behaviors. | `54_band-detail__members.png` (row has role chips but no name), `91_create-rehearsal__form-top.png` (blank chip), `97_rehearsal-detail__millennium.png` ("Coming: …, benjamin@sevengood.com") | One shared fallback everywhere: email local-part or "Invited member". Never render an empty row/chip. |

---

## P1 — high-value fixes

| # | Finding | Evidence | Fix |
|---|---------|----------|-----|
| P1-1 | **Key filter can't match real data.** Filter offers only C…B with sharps; the library shows `Ab` (flat) and `em` (minor) badges. Songs become unfindable via filter with no explanation. | `08_songs__filters-popup.png` vs `99` (Ab on Don't Stop), `15` (em on Hey Joe) | Match enharmonics (Ab⇄G#) in the filter logic; add minor keys or a major/minor toggle. |
| P1-2 | **Quick-action picker sheet has no title.** It's a radio list (Practice mode / Tuner / Performance sheet / Spotify / Add to band) that *sets the card's default action* — but looks like an action menu. Users will tap expecting the action to run. | `13_songs__quick-action-picker.png` | Add a header: "Quick action — what the ⏱ button on a song card does", and a confirmation toast on change. |
| P1-3 | **"Practice mode" opens a screen titled "Metronome"**, and the bottom nav highlights **Home** even when entered from Songs. | `12_songs__song-card-menu.png` → `27_practice-mode__main.png` | Title the screen "Practice" (or rename the menu item); keep the originating tab highlighted. |
| P1-4 | **Band detail is a Home clone.** "Hello, Teplo! Ready to rock?" greets the *band*; the band's content sits under a "My Library" heading; Quick Actions/Tools duplicate Home. New users can't tell whose data they're looking at. | `45_band-detail__songs-tab.png` | Drop the greeting card, rename heading to "Band library", keep only band-specific actions. |
| P1-5 | **"Song Bank" is a mislabeled alias of the Songs tab.** The Home quick action promises something new and routes to the identical Songs screen. | `43_song-bank__main.png` (title: "Songs") | Remove the quick action or make it a real feature; don't ship two names for one screen. |
| P1-6 | **Two overlapping FABs on My Bands** (join-band person+ FAB half-hidden behind the create + FAB), and FABs cover the last list item on Songs/Bands lists. | `44_bands__list.png` (stacked FABs over Funk Foundry card), `15_songs__list-scroll2.png` | One FAB per screen (create); move Join into the header or empty state. Add bottom list padding equal to FAB height. |
| P1-7 | **Opening a setlist lands directly in Edit mode** with a Save Changes button — no read-only view. Accidental reorder/edit is one touch away, and viewers see an editor they may not be allowed to use. | `69_setlist-detail__main.png` (title "Edit Setlist") | Read-only detail first (big Play/Perform action), explicit Edit entry. |
| P1-8 | **Every ⋮ menu ends with Keep screen on / Profile / Sign out.** On some screens (Duplicate songs, Home) the menu contains *only* these. Sign out is one mistap away everywhere, and real screen actions (Performance sheet, Import) drown among account items. | `01`, `17_edit-song__overflow-menu.png`, `28`, `46`, `103_duplicate-songs__overflow-menu.png` | Keep screen on → a settings toggle; Profile/Sign out live in the Profile tab only. Hide ⋮ when a screen has no own actions. |
| P1-9 | **Performance sheet empty state is a dead end** — "Add them to a section…" with no button; the path (back → ⋮ → Song editor / Import) must be guessed. | `18_performance-sheet__main.png` | Add CTA buttons: "Open song editor" / "Import lyrics & chords". |
| P1-10 | **Structure editor: red trash on every section sits next to the drag handle**; no Add-section control visible on any captured scroll; "Duration: 2 phrases" is jargon and looks like an unedited default on all sections. **Correction (code review):** a "Delete Section" confirmation dialog already exists (`song_constructor.dart:125`) — the capture never tapped delete, so the audit couldn't see it. The Fitts adjacency risk (trash beside drag handle) stands; the no-confirmation claim does not. | `23`–`25_edit-song__structure-editor*.png` | Swipe-to-delete (or overflow) instead of inline trash; visible "+ Add section"; human wording ("2 phrases" → configurable bars/phrases with explanation). |
| P1-11 | **Create Band subtitle promises "Invite your bandmates"** but the screen has no invite step (invite exists only after creation, on About → Invite). | `60_create-band__form.png`, invite at `57_band-detail__invite.png` | Change copy to "You can invite members after creating", or route to the invite screen right after creation. |
| P1-12 | **Unlabeled pickers:** the Rehearsals band-picker sheet has no title (just a bare list of bands over Home), and the member-role sheet doesn't say *whose* role you're editing. | `64_rehearsals__band-picker.png`, `55_band-detail__member-menu.png` | Add sheet headers: "Rehearsals — choose band", "Role — Andrey Dyakov". |

---

## P2 — polish

| # | Finding | Evidence |
|---|---------|----------|
| P2-1 | Add Song shows key "C" in the Key & BPM row before the user picked anything — looks like prefilled data and will be saved as wrong metadata. | `38_add-song__form.png` |
| P2-2 | Two search affordances on the song form: "Search a song to autofill…" field and a floating "Search web" link bottom-right with no context. | `38`, `16_edit-song__details-top.png` |
| P2-3 | BPM filter presets ("60 BPM … 180 BPM") don't say whether they mean exact/±/threshold; the dropdown is an unstyled platform list that covers the sheet. | `09_songs__bpm-dropdown.png` |
| P2-4 | Key badge styling is inconsistent: orange badges on some cards, gray on others, with no discernible rule; setlist editor shows "-" dash badges for missing keys and unlabeled slider/speedometer icons per row. | `15`, `99`, `69` |
| P2-5 | Sort control label "Manual" (Bands, Setlists) is cryptic — "Manual order" or an icon-only affordance would read better. | `44`, `68` |
| P2-6 | Metronome beat/subdivision dot rows are unlabeled; and +5/+1 are orange while −5/−1 are gray, implying minus is disabled. | `27_practice-mode__main.png` |
| P2-7 | Tempo ramp sheet: label reads "Advance every bars" (broken grammar with the "Every 4" field); the Bars/Seconds segmented control uses a white selected state while every other control selects in orange. | `35_practice-mode__ramp-settings.png` |
| P2-8 | Haptics is controllable in two places with different UI (menu item "On" + toggle inside the Sound sheet); the menu shows Sound "Click ›" while the sheet actually selects waveforms (Sine/Square/…). | `28`, `29` |
| P2-9 | "Song editor (map + ChordPro)" — jargon in a menu item; new users don't know either term. | `17` |
| P2-10 | Profile: "My Roles" appears twice (section header + card header); Sign Out is red text while Delete account is a quiet underlined link — the more destructive action looks less guarded. | `78`, `82_profile__scroll2.png` |
| P2-11 | About band: date "Created 27/2/2026" (locale-ambiguous); unexplained orange star icons per member; band avatar is gray on detail but orange on About. | `54`, `45` |
| P2-12 | Tuner: bottom-left circle button is completely empty (no icon/label); bottom nav highlights Home inside the tool. | `84_tuner__main.png` |
| P2-13 | Empty states duplicate their CTA with the FAB on the same screen (band songs/setlists/rehearsals). Harmless but noisy. | `48`, `51`, `65` |
| P2-14 | Song cards change height depending on whether BPM exists — badges jump between rows; reserve the slot for alignment. | `99` (Bulls on Parade vs Back To Black) |
| P2-15 | Rehearsal five days in the past still shows as "Confirmed" with no past/upcoming distinction in the list. | `96_rehearsals__millennium-list.png` (Jul 9, captured Jul 14) |

---

## Nielsen heuristic evaluation

Method: heuristic walkthrough of all 105 captured screens against Nielsen's 10 usability heuristics. Severity uses Nielsen's scale: **0** not a problem · **1** cosmetic · **2** minor · **3** major · **4** usability catastrophe. Findings from the priority lists above are cross-referenced by ID; issues first surfaced by this pass are marked **new**.

### H1 — Visibility of system status

| Sev | Issue | Ref |
|-----|-------|-----|
| 3 | Screen blanks entirely after dismissing a menu instead of keeping state visible — the system appears to have lost the user's data. | P0-3, `74`, `80` |
| 3 | Changing the quick action in the picker gives no feedback (no toast, no visible change on the card — the icon stays a speedometer regardless of the chosen action). User can't tell the setting took effect. | P1-2 + **new**, `13`, `14` |
| 2 | No sync/offline indicator anywhere. In a band app where another member can edit shared data, users can't tell if what they see is current or when it last synced. | **new**, all screens |
| 2 | A past rehearsal (Jul 9, viewed Jul 14) still displays as "Confirmed" with no visual past/upcoming distinction. | P2-15, `96` |
| 1 | Concert Mode menu item shows no on/off state, unlike its neighbors Count-in (Off), Ramp (Off), Haptics (On). | **new**, `28` |

### H2 — Match between system and the real world

| Sev | Issue | Ref |
|-----|-------|-----|
| 3 | Key filter speaks in sharps-major only while musicians' data uses flats and minors (`Ab`, `em`). The system's vocabulary doesn't match the domain's. | P1-1, `08` |
| 2 | "Duration: 2 phrases" — "phrases" is not how most musicians count section length (bars/measures are). | P1-10, `23` |
| 2 | Jargon in user-facing labels: "Song editor (map + ChordPro)", "AI access (MCP)". | P2-9, `17`, `78` |
| 2 | "Song Bank" implies a distinct repository; it opens the plain Songs library. | P1-5, `43` |
| 1 | "Advance every bars" — broken natural language in the ramp sheet. | P2-7, `35` |

### H3 — User control and freedom

| Sev | Issue | Ref |
|-----|-------|-----|
| 4 | System back exits the app from Tuner and Join Band — the universal "emergency exit" (back) destroys the session instead of undoing navigation. | P0-1, P0-2, `85`, `63` |
| 3 | Setlists open directly in Edit mode; there is no read-only view to retreat to, and no visible Cancel — only Save Changes. Whether backing out discards silently is untested, but neither outcome is communicated. | P1-7, `69` |
| 3 | No undo anywhere: deleting a structure section, removing a member, unloading the practice song (X on the chip) are all one-tap with no undo affordance. | **new** + P1-10, `23`, `55`, `27` |
| 2 | Edit Song has Save Changes but no explicit Cancel/discard control; leaving via back is the only escape and its effect is uncommunicated. | **new**, `16` |

### H4 — Consistency and standards

| Sev | Issue | Ref |
|-----|-------|-----|
| 3 | Missing display name renders three different ways on three screens (blank row / empty chip / raw email). | P0-5, `54`, `91`, `97` |
| 3 | Entry point says "Practice mode", destination titles itself "Metronome"; bottom nav highlights the wrong tab (Home) inside Practice and Tuner. | P1-3, `27`, `84` |
| 2 | Selection color language breaks per screen: orange chips (tags, count-in) vs white segmented control (ramp Bars/Seconds) vs unstyled platform dropdown (BPM). | P2-7, P2-3, `32`, `35`, `09` |
| 2 | Key badges styled orange on some cards, gray on others, with no rule; "-" dash badge for missing keys in the setlist editor. | P2-4, `15`, `69` |
| 2 | Same control, two homes: Haptics is a menu item in Practice overflow and a toggle in the Sound sheet; menu says Sound: "Click" while the sheet selects waveforms (Sine/…). | P2-8, `28`, `29` |
| 2 | Band detail reuses Home's template ("Hello, Teplo!", "My Library") so identical UI means different data scopes on different screens. | P1-4, `45` |
| 1 | Band avatar gray on detail, orange on About; "My Roles" header duplicated; sort labeled "Manual". | P2-11, P2-10, P2-5 |

### H5 — Error prevention

| Sev | Issue | Ref |
|-----|-------|-----|
| 3 | Red delete icon on every structure section sits directly beside the drag handle — reorder attempts will hit delete, and no confirmation was observed. | P1-10, `23` |
| 3 | Sign out is reachable from the ⋮ of every screen, adjacent to frequently used items. | P1-8, `01`, `28` |
| 2 | Add Song displays key "C" before any user choice — invites saving wrong metadata by default. | P2-1, `38` |
| 2 | Member-role sheet doesn't name the member being edited — wrong-target changes are easy with similar rows. | P1-12, `55` |
| 2 | "Remove from band" sits in the same small sheet as role radio buttons, one tap below "Edit music roles". | **new**, `55` |

### H6 — Recognition rather than recall

| Sev | Issue | Ref |
|-----|-------|-----|
| 3 | The song-card speedometer button's meaning is whatever the user once set in the quick-action picker — nothing on the card reveals the current assignment; users must recall it. | P1-2 + **new**, `13` |
| 2 | Metronome beat/subdivision dot rows are unlabeled — users must recall which row is which. | P2-6, `27` |
| 2 | Song Structure summary bar uses unexplained colors (cyan/teal/yellow) with no legend, and Verse/Chorus share a color. | **new**, `16` |
| 2 | Rehearsals band-picker sheet is an untitled list — no context for what choosing a band will do. | P1-12, `64` |
| 1 | Unexplained orange star icons on member rows. | P2-11, `54` |

### H7 — Flexibility and efficiency of use

| Sev | Issue | Ref |
|-----|-------|-----|
| 2 | No search/filter persistence hints, no recent/pinned songs; every practice session starts from scrolling the full list. | **new**, `03` |
| 2 | No batch operations in Songs (multi-select for add-to-band / tag / delete) — heavy libraries (39 songs here) are managed one card menu at a time. | **new**, `12` |
| 1 | Good accelerators exist and should be kept: CSV import/export, QR invite, "Save to song" from practice mode. | `100`, `57`, `28` |

### H8 — Aesthetic and minimalist design

| Sev | Issue | Ref |
|-----|-------|-----|
| 3 | Practice overflow menu holds 12 items across four concerns (playback settings, practice settings, song CRUD, account). | P1-8, `28` |
| 2 | Every screen carries the global ⋮ even when empty of screen actions (Duplicate songs, Home). | P1-8, `103` |
| 2 | Duplicate CTAs: empty-state button + FAB on the same screens; two search entries on the song form. | P2-13, P2-2, `48`, `38` |
| 2 | Two stacked FABs on My Bands, one half-occluded. | P1-6, `44` |
| 1 | Tuner's empty circular button (no icon, no label). | P2-12, `84` |

### H9 — Help users recognize, diagnose, and recover from errors

| Sev | Issue | Ref |
|-----|-------|-----|
| 3 | Key-filtering silently returns fewer songs than the user owns (enharmonic/minor mismatch) with no "0 results because…" explanation. | P1-1, `08` |
| 2 | Setlist card menu offers Share/Export but no rename/delete — recovering from a mistyped name ("testo tiras") requires discovering the edit screen. | **new**, `73` |
| — | **Coverage gap:** no error, offline, or failed-save states were captured (deliberately — read-only audit). Network failure, invalid invite code, and conflicting band edits need a follow-up live pass before beta widening. | — |

### H10 — Help and documentation

| Sev | Issue | Ref |
|-----|-------|-----|
| 2 | No onboarding, hints, or contextual help observed anywhere in 105 screens — combined with jargon (ChordPro, phrases, MCP, Concert Mode) there is no in-app path to learn these concepts. | **new**, `17`, `28`, `78` |
| 2 | Empty states are the app's only teaching surface and are well-written — but one (performance sheet) teaches without providing the action it names. | P1-9, `18` |
| 1 | "Members (tap: Required → Optional → off)" crams interaction documentation into a field label — better as an inline hint on first use. | **new**, `91` |

### Heuristic scorecard

| Heuristic | Worst sev | Count | Weakest spots |
|-----------|-----------|-------|---------------|
| H1 Status visibility | 3 | 5 | Blank repaint, silent quick-action setting |
| H2 Real-world match | 3 | 5 | Key vocabulary vs musician data |
| H3 Control & freedom | **4** | 4 | Back exits app; no undo; edit-only setlists |
| H4 Consistency | 3 | 7 | Name fallbacks, titles, selection colors |
| H5 Error prevention | 3 | 5 | Inline destructive icons, global Sign out |
| H6 Recognition > recall | 3 | 5 | Invisible quick-action assignment |
| H7 Flexibility | 2 | 3 | No batch ops; good accelerators exist |
| H8 Minimalism | 3 | 5 | Overloaded menus, duplicate CTAs |
| H9 Error recovery | 3 | 2+gap | Silent filter loss; error states unaudited |
| H10 Help | 2 | 3 | No onboarding; jargon unexplained |

The two weakest heuristics are **H3 (user control)** — the only severity-4 in the audit — and **H4 (consistency)**, which accumulates the most individual violations. This matches the cross-cutting themes below: fix back-stack ownership and define shared fallbacks/naming, and both columns collapse.

---

## HEART framework analysis (Google)

HEART is a metrics framework, so a static-screenshot audit can do two things: (a) flag which audit findings threaten each dimension, and (b) define the Goals → Signals → Metrics to instrument **before widening the beta**, so the fixes above become measurable. Today the app appears to have no analytics surface for any of these (no events observed; nothing in Profile suggests telemetry consent) — every metric below implies instrumentation work.

### H — Happiness
*Goal: the app feels trustworthy and polished enough that musicians recommend it to bandmates.*

| Audit threats | Signals | Metrics to instrument |
|---|---|---|
| Blank-screen repaints (P0-3), count mismatches (P0-4), nameless members (P0-5) — each erodes perceived reliability; naming drift (P1-3/P1-5) reads as unfinished. | User expresses satisfaction or frustration; support contact; store review. | In-app 1-tap PMF/CSAT prompt after the 3rd session; Play Store rating trend; support contacts (Telegram/WhatsApp, `82`) per weekly active user. |

### E — Engagement
*Goal: the app becomes part of the practice routine, not just a song list.*

| Audit threats | Signals | Metrics to instrument |
|---|---|---|
| The strongest engagement surfaces (Practice mode, performance sheet, ramp) are buried in overflow menus (P1-8) or dead-end when empty (P1-9); no recents/pinning makes each session start with scrolling (H7). | Repeated practice/tuner/metronome sessions; songs and setlists grow over time. | Practice sessions per active user per week; median practice session length; songs added per user per week; % of sessions that use a tool (practice/tuner/metronome) vs only browse. |

### A — Adoption
*Goal: an invited musician becomes an active band member.*

| Audit threats | Signals | Metrics to instrument |
|---|---|---|
| **P0-2 directly poisons the core adoption loop**: the invite deep link lands on Join Band, where system back kills the app. Join form gives no context about the band before "Find Band" (`62`). Create Band promises invites it doesn't deliver (P1-11). | Invite created → opened → joined → first shared content seen. | Invite funnel conversion (QR/link generated → link opened → join completed → band opened); D1 activation rate (new user adds ≥1 song or joins ≥1 band); % of new users arriving via invite vs organic. |

### R — Retention
*Goal: bands keep coordinating here (rehearsals + shared setlists are the retention hooks).*

| Audit threats | Signals | Metrics to instrument |
|---|---|---|
| Rehearsals are hidden under Home→Tools (`00`) and behind an untitled picker (P1-12); past rehearsals show as "Confirmed" (P2-15), making the surface feel stale; single-member bands (7 of 8 here have ≤3 members) provide no pull. | Users return without prompting; bands schedule repeatedly. | W1/W4 user retention; % of bands with ≥2 members active in the same week; rehearsals created per band per month; setlist edits by a second member (proxy for real collaboration). |

### T — Task success
*Goal: core tasks complete quickly and without silent failure.*

| Audit threats | Signals | Metrics to instrument |
|---|---|---|
| Key filter silently loses songs (P1-1); quick-action changes give no confirmation (H1); setlist opens in edit mode risking accidental changes (P1-7); back-exits abort tasks entirely (P0-1/2). | Searches end in opening a song; filters return results; flows complete without app exit. | Filter-applied → zero-results rate (with key-type breakdown — will directly expose P1-1); search → song-open rate; setlist-create completion time; **count of app exits via system back from non-root screens** (regression metric for P0-1/2); crash-free session rate. |

**Priority instrumentation order for beta:** the P0 regression metrics first (back-exit counter, crash-free rate), then the adoption funnel (it's the growth loop), then task-success rates. Happiness prompts can wait until the P0 fixes ship — measuring satisfaction before fixing known catastrophes just documents the obvious.

---

## Fitts's Law analysis

Context: 1260×2800 px portrait phone (~20:9). At this size the comfortable thumb zone is the bottom third; the top corners are the most expensive targets (grip change or second hand). Android's minimum touch target is 48dp ≈ ~132 px at this density. Sizes below are estimated from the screenshots.

### What follows the law well

| Pattern | Evidence |
|---|---|
| **Bottom nav** — five large, edge-anchored, always-in-thumb-zone targets. Edge targets have effectively infinite depth (no overshoot). | all screens |
| **Practice dial** — the highest-frequency control (tempo) is a huge drag surface (~700 px) dead center, with a ~200 px Play button beneath it in the thumb zone. The −5/−1/+5/+1 satellites (~150 px) hug the dial, minimizing travel between coarse and fine adjustment. | `27` |
| **Bottom sheets for choices** (count-in, sound, quick action, member role) — full-width rows ≥120 px tall land options directly under the thumb instead of at the top of the screen. | `13`, `29`, `32`, `55` |
| **Sticky full-width CTAs** (Save Changes, Create Band, Start ramp) — ~1180×170 px targets at the bottom edge; essentially impossible to miss. | `16`, `60`, `35` |

### Violations

| Sev | Issue | Fitts mechanics | Ref |
|-----|-------|-----------------|-----|
| 3 | **Delete (trash) sits ~80 px from the drag handle on every structure section**, both ~90 px targets. Reordering is a high-frequency *drag* that begins with a press adjacent to a destructive *tap* — small distance between small targets with opposite consequences maximizes error probability (compounds the H5 finding: no confirmation). | Small adjacent targets, opposite outcomes | `23` |
| 3 | **Two stacked FABs on My Bands**: the join FAB (~120 px) is partially occluded by the create FAB (~180 px) at ~60 px separation. Overlapping targets make the smaller one nearly unhittable and mis-hits land on "create". | Occlusion + adjacency | `44` |
| 2 | **Every screen's actions live in the top corners** — back top-left, ⋮ top-right (~120 px targets at maximum distance from the thumb's resting position). On this aspect ratio those are two-hand or grip-shift targets, yet the ⋮ is the *only* route to core features (performance sheet, import, find duplicates). High-value actions carry the highest acquisition cost on the screen. | Max distance, moderate size | `16`, `99` |
| 2 | **"Search web" is a small text link (~330×90 px) floating directly above the giant sticky Save button.** Undershooting the link by ~40 px commits the form instead. Same class as the trash/drag issue: small utility target adjacent to a huge commit target. | Small target adjacent to huge target | `16`, `38` |
| 2 | **Song-card right edge stacks two ~100 px icon targets** (quick-action speedometer, kebab) ~110 px apart, and on the last visible card the FAB (~180 px) overlaps the same corner — three interleaved targets in one thumb-width column. | Target crowding | `15`, `99` |
| 2 | **The X to unload the practice song (~90 px)** sits inside the tappable song chip; missing the X by a few px triggers the chip's own action. | Nested targets | `27` |
| 1 | **Tag filter chips** are comfortably sized (~150–330×130 px) but the row starts at x≈35 px — the leftmost "All" chip is a screen-edge reach-around for right-handed use; horizontal scroll mitigates. | Minor travel cost | `04` |
| 1 | **Tuner's dead button**: an empty ~150 px circle occupies premium bottom-left thumb-zone real estate while doing nothing visible — spending the best Fitts position on a no-op. | Wasted prime position | `84` |

### Recommendations (ordered by leverage)

1. **Separate destruction from manipulation** in the structure editor: drag handle stays right, delete moves behind swipe or the row's overflow. This single change resolves the worst Fitts violation and an H5 finding together.
2. **One FAB per screen** (P1-6): create only; Join Band belongs in the header or the empty state.
3. **Stop making the top-right ⋮ the sole path to core features** (P1-8): promote Performance sheet / Practice into on-card or bottom-of-screen affordances; the menu cleanup and the Fitts cost reduction are the same work.
4. **Give "Search web" a real button with clearance** from the Save CTA (≥48 dp vertical gap or move it into the autofill field as a trailing action).
5. **Reserve bottom padding under lists** equal to FAB height + margin so the last card's controls are never occluded (`15`, `44`).

---

## Cross-cutting themes

1. **Back-stack ownership.** Both P0 nav bugs plus the wrong-tab highlights (Practice/Tuner showing "Home") point to routes being pushed outside the shell navigator. One routing review fixes the class, not just the two instances.
2. **Global items leaking into contextual menus.** Keep screen on / Profile / Sign out belong to exactly one place. Removing them from every ⋮ shrinks nine menus and eliminates the accidental-signout risk.
3. **One data model, three renderings.** Missing display names, missing keys ("-"), missing BPM (collapsing rows) — each screen improvises its own fallback. Define fallbacks once (name → email local-part; key/BPM → hide row consistently or show placeholder).
4. **Naming discipline.** Practice mode/Metronome, Song Bank/Songs, "My Library" inside a band, "Manual" sort. A 30-minute naming pass over screen titles, menu items, and quick actions would noticeably raise perceived quality.
5. **Selection color language.** Orange = selected works well in tag chips and count-in; the ramp sheet (white selection), BPM dropdown (platform default), and asymmetric +/− buttons break it.
6. **Empty states are a strength** — keep the copy voice ("Propose a time and let the band vote", "Add songs to your band's collection"), just make sure each one has a working CTA (the performance sheet is the one dead end).

---

## Per-screen appendix

| Area | Screenshots | Verdict / notes |
|------|-------------|-----------------|
| Home | `00`, `01` | Solid layout. Rehearsals hidden under "Tools" is debatable; Song Bank quick action misleading (P1-5); ⋮ has only global items (P1-8). |
| Songs list + filters | `03`–`15`, `98`–`100` | Good: search+sort+tags+count. Issues: key filter mismatch (P1-1), quick-action sheet (P1-2), FAB over last card (P1-6), badge inconsistency (P2-4), BPM presets (P2-3). |
| Edit Song | `16`, `17`, `22`, `26` | Clean card structure. "Search web" floating link (P2-2), jargon menu item (P2-9), features buried in ⋮ (P1-8). |
| Structure editor | `23`–`25` | Inline trash + jargon + no visible add (P1-10). |
| Performance sheet | `18`–`21` | Dead-end empty state (P1-9); PDF export options well-written. |
| Practice mode | `27`–`36` | Powerful; naming/title mismatch (P1-3), unlabeled beat rows (P2-6), ramp grammar/selection color (P2-7), duplicated haptics (P2-8). |
| Add Song | `38`–`41` | Preset "C" (P2-1), dual search entries (P2-2). |
| Song Bank | `43` | Alias of Songs (P1-5). |
| Bands list | `44` | Stacked/overlapping FABs (P1-6), "Manual" sort (P2-5). |
| Band detail | `45`–`53` | Home clone (P1-4); band songs/setlists empty states good (P2-13 duplication). |
| About band / members / invite | `54`–`59` | Nameless member row (P0-5), role sheet without member name (P1-12), stars/date/avatar-color nits (P2-11). Invite screen (`57`) is the best screen in the app. |
| Create / Join band | `60`–`63` | Copy promise mismatch (P1-11); back-exit bug from Join (P0-2). |
| Rehearsals | `64`–`67`, `89`–`97` | Picker sheet untitled (P1-12), nameless-member chip (P0-5), email fallback (P0-5), past rehearsal shown as current (P2-15). Empty-state copy excellent. |
| Setlists | `68`–`77` | Count mismatch (P0-4), edit-only detail (P1-7), blank repaint (P0-3), card menu lacks rename/delete while song cards have rich menus. |
| Profile | `78`–`82` | Double header (P2-10), Delete account underweighted vs Sign Out (P2-10). |
| Tuner / Metronome | `84`, `87` | Back-exit bug (P0-1), empty button (P2-12), wrong nav highlight. |
| Duplicate songs | `100`–`103` | Fine; ⋮ with only global items (P1-8). Empty state clear. |

---

*Suggested next step: fix the P0 list before widening the beta cohort — all five are visible within a new user's first session. P1-1/P1-2/P1-3 are the highest-leverage quick wins after that.*

---

## Remediation log (updated 2026-07-15)

- **Phase 1** (PR #101): P0-1, P0-2, P0-4, P0-5 fixed + `setlistsProvider` hang hardening. Device-verified 0/3 back-exits.
- **Phase 2** (PR #102): P1-5, P1-6, P1-8 (partial), P1-11, P1-12, P2-5, P2-7, P2-10 + Practice placeholder (AUDIT_addition.md scope).
- **Phase 3** (PR #103): P1-1 (G# finds Ab on device), P1-2, P1-7, P1-9; P1-10 corrected (confirm dialog already existed).
- **Phase 5** (PR #104): bottom-first navigation. P1-8 fully closed (no global items anywhere; Menu sheet with screen-title headers). Fitts top-corner rows closed — **0 interactive controls in the top 15% of the screen**. Nielsen H3 "no undo" (sev 3): single-level snackbar undo at section delete / setlist delete / setlist-song removal / practice unload (member removal keeps its dialog — server-authoritative). H3 web/PWA back gap closed: in-app Back in the bottom bar on every pushed screen. P2-8 resolved (menu values folded into labels; live toggles in-sheet).
- Re-grade: Nielsen H3 worst severity 4 → 1 (remaining: editors have no multi-step undo — deliberate ceiling). Fitts violations table: rows 1 (structure trash — now undoable), 3 (top-corner ⋮), and title-slot issues closed; FAB-adjacency rows remain open.
- Pending: Phase 4 HEART instrumentation (`back_used{ui|system}`, `menu_opened`, `undo_shown/undo_used` among the planned events).
- **Phase 6** (PR #105): top app bars removed entirely (roots: tab = location; pushed: title in bottom bar — the Fitts "0 controls up top" goal now includes 0 dead rows). **P0-4 truly closed**: setlist counts = raw entry count; orphaned entries render as removable "Unavailable song" rows; the editor's silent orphan deletion on save (data loss, found in re-investigation) fixed; metronome plays partial queues; merge rewrites `items`. P1-4 closed (band screen de-cloned). P2-1/2/3/4/6/11/12/15 closed — notably P2-12's "dead" tuner button was a live mic level meter missing its icon.
- **Phase 4/6E** (PR #106): HEART instrumentation live — consent-gated (Profile switch) `back_used`/`menu_opened`/`undo_shown`/`undo_used`/`filter_zero_results`/invite-funnel/engagement/retention events through the existing AnalyticsService; `menu_opened` + `back_used` verified on device via FA logging. In-app review prompt deliberately deferred (store-policy decision).

**Remediation complete: PRs #101–#106.** Remaining open audit items (small): FAB-adjacency Fitts rows, add-song Save bar stacking, landscape-rail primary action, H7 batch operations, H10 onboarding, editor multi-step undo — all deliberate deferrals, none P0/P1.
